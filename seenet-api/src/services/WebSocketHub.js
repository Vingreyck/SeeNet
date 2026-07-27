const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const logger = require('../config/logger');

// Admin com o mapa de UMA OS aberto (rastreamento_mapa_screen).
const assinantesPorOS = new Map(); // "tenantId:osId" -> Set<ws>
// Admin com a tela de acompanhamento aberta (lista de todas as OSs em campo).
const assinantesGeral = new Map(); // tenantId -> Set<ws>

// Sem autenticar em 10s → derruba (socket anônimo não fica ocupando recurso).
const TIMEOUT_AUTH_MS = 10000;
// Heartbeat: ping de protocolo (detecta socket morto AQUI) + ping de aplicação
// (o cliente Dart não enxerga o ping de protocolo, então precisa deste pra saber
// que a conexão está viva). Também segura o proxy do Railway, que derruba
// conexão ociosa.
const HEARTBEAT_MS = 25000;
// Anti-abuso: teto de mensagens recebidas por janela (subscribe faz query no
// banco — sem isso um cliente com bug/malicioso poderia martelar o Postgres).
const MAX_MSGS_JANELA = 30;
const JANELA_MS = 10000;

const chaveOS = (tenantId, osId) => `${tenantId}:${osId}`;

/** Tira o ws da inscrição de OS e apaga o Set que ficou vazio (senão o Map
 *  cresce pra sempre: 1 entrada morta por OS já acompanhada). Usada sozinha
 *  ao trocar de técnico sem fechar o socket. */
function desinscreverOS(ws) {
  if (!ws.chaveOsInscrita) return;
  const set = assinantesPorOS.get(ws.chaveOsInscrita);
  if (set) {
    set.delete(ws);
    if (set.size === 0) assinantesPorOS.delete(ws.chaveOsInscrita);
  }
  ws.chaveOsInscrita = null;
}

/** Tira o ws de TODAS as listas (usada ao fechar a conexão). */
function desinscrever(ws) {
  desinscreverOS(ws);
  if (ws.geralInscrito && ws.tenantId != null) {
    const tid = ws.tenantId.toString();
    const set = assinantesGeral.get(tid);
    if (set) {
      set.delete(ws);
      if (set.size === 0) assinantesGeral.delete(tid);
    }
    ws.geralInscrito = false;
  }
}

/** Envia só se o socket estiver aberto e sem congestionamento. Se o cliente
 *  parou de ler (celular ruim/rede travada), o buffer cresce e comeria a RAM
 *  do servidor — nesse caso derruba: ele reconecta e o polling cobre o vão. */
function enviar(ws, msg) {
  if (ws.readyState !== ws.OPEN) return;
  if (ws.bufferedAmount > 1024 * 256) {
    ws.terminate();
    return;
  }
  try {
    ws.send(msg);
  } catch (_) {}
}

/**
 * Hub de WebSocket p/ empurrar a posição do técnico pro admin na hora (em vez
 * do admin ficar só no polling). ADITIVO: o PUT/GET /location por HTTP
 * continuam existindo do jeito que estão (fallback se o WS cair/não conectar
 * — ex.: rede que bloqueia WS, ou app antigo sem esse recurso ainda).
 *
 * O técnico NÃO escreve por aqui — ele continua mandando a posição por HTTP
 * (PUT /location), que é quem persiste no banco e tem fila offline. O WS é só
 * o "fan-out" da leitura pro admin, então uma queda dele nunca perde dado.
 */
function init(httpServer) {
  // noServer + upgrade manual: assim dá pra DERRUBAR upgrade em path errado
  // (com a opção `path` o ws só ignora, e o socket fica pendurado).
  // maxPayload baixo: as mensagens daqui são minúsculas (auth/subscribe).
  const wss = new WebSocketServer({ noServer: true, maxPayload: 4096 });

  httpServer.on('upgrade', (req, socket, head) => {
    let pathname = '';
    try {
      pathname = new URL(req.url, 'http://localhost').pathname;
    } catch (_) {}
    if (pathname !== '/ws') {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit('connection', ws, req));
  });

  wss.on('connection', (ws) => {
    ws.autenticado = false;
    ws.isAlive = true;
    ws.msgsJanela = 0;
    ws.janelaInicio = Date.now();
    ws.on('pong', () => { ws.isAlive = true; });

    // Derruba quem conectar e não autenticar (porta aberta pra qualquer um).
    ws.timerAuth = setTimeout(() => {
      if (!ws.autenticado) ws.terminate();
    }, TIMEOUT_AUTH_MS);

    ws.on('message', async (raw) => {
      // Rate limit por janela deslizante simples.
      const agora = Date.now();
      if (agora - ws.janelaInicio > JANELA_MS) {
        ws.janelaInicio = agora;
        ws.msgsJanela = 0;
      }
      if (++ws.msgsJanela > MAX_MSGS_JANELA) {
        ws.terminate();
        return;
      }

      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch (_) {
        return;
      }

      if (msg.type === 'auth') {
        if (ws.autenticado) return; // já autenticado: ignora re-auth
        try {
          const decoded = jwt.verify(msg.token, process.env.JWT_SECRET);
          const user = await db('usuarios')
            .join('tenants', 'usuarios.tenant_id', 'tenants.id')
            .where('usuarios.id', decoded.userId)
            .where('tenants.codigo', msg.tenantCode)
            .whereRaw('usuarios.ativo = ?', [true])
            .whereRaw('tenants.ativo = ?', [true])
            .select('usuarios.id', 'usuarios.tipo_usuario', 'tenants.id as tenant_id')
            .first();

          if (!user) {
            enviar(ws, JSON.stringify({ type: 'auth_erro', error: 'Usuário/empresa inválido' }));
            return ws.close();
          }

          ws.autenticado = true;
          ws.userId = user.id;
          ws.tenantId = user.tenant_id;
          ws.isAdmin = user.tipo_usuario === 'administrador';
          // Guarda o vencimento do token: conexão fica aberta por horas/dias,
          // então revalidamos no heartbeat (senão um token expirado seguiria
          // recebendo dados pra sempre).
          ws.tokenExp = decoded.exp ? decoded.exp * 1000 : null;
          clearTimeout(ws.timerAuth);
          enviar(ws, JSON.stringify({ type: 'auth_ok' }));
        } catch (e) {
          enviar(ws, JSON.stringify({ type: 'auth_erro', error: 'Token inválido' }));
          ws.close();
        }
        return;
      }

      // Ignora qualquer outra mensagem antes de autenticar.
      if (!ws.autenticado) return;

      if (msg.type === 'subscribe_os' && ws.isAdmin && msg.osId) {
        const osId = parseInt(msg.osId, 10);
        if (!osId || isNaN(osId)) return;

        // 🔒 A OS precisa ser DESTE tenant. Sem esta checagem, um admin de uma
        // empresa poderia se inscrever num id de OS de OUTRA empresa e receber
        // a localização dos técnicos dela (o id é só um número — dava pra
        // adivinhar). Mesma regra do GET /location (tenant + ser admin).
        const os = await db('ordem_servico')
          .where('id', osId)
          .where('tenant_id', ws.tenantId)
          .select('id')
          .first();
        if (!os) {
          enviar(ws, JSON.stringify({ type: 'subscribe_erro', error: 'OS não encontrada' }));
          return;
        }

        // Trocar de OS sem fechar o socket (voltar no mapa e abrir outro
        // técnico) precisa TIRAR da inscrição antiga — senão o admin
        // continuaria recebendo a posição do técnico anterior pra sempre.
        desinscreverOS(ws);
        const chave = chaveOS(ws.tenantId, osId);
        ws.chaveOsInscrita = chave;
        if (!assinantesPorOS.has(chave)) assinantesPorOS.set(chave, new Set());
        assinantesPorOS.get(chave).add(ws);
        return;
      }

      if (msg.type === 'unsubscribe_os') {
        desinscreverOS(ws);
        return;
      }

      if (msg.type === 'subscribe_geral' && ws.isAdmin) {
        const tid = ws.tenantId.toString();
        if (!assinantesGeral.has(tid)) assinantesGeral.set(tid, new Set());
        assinantesGeral.get(tid).add(ws);
        ws.geralInscrito = true;
        return;
      }
    });

    ws.on('close', () => {
      clearTimeout(ws.timerAuth);
      desinscrever(ws);
    });

    ws.on('error', () => {}); // evita crash em erro de socket (ex.: reset de conexão)
  });

  const intervalo = setInterval(() => {
    const agora = Date.now();
    wss.clients.forEach((ws) => {
      // Socket que não respondeu o ping anterior = morto.
      if (ws.isAlive === false) return ws.terminate();
      // Token venceu no meio da conexão → derruba (o app reconecta e, se o
      // token local ainda valer, entra de novo; se não, cai no polling).
      if (ws.tokenExp && agora > ws.tokenExp) return ws.terminate();

      ws.isAlive = false;
      ws.ping(); // nível protocolo: detecta morto AQUI no servidor
      // nível aplicação: é o que o cliente Dart consegue enxergar pra saber
      // que a conexão está viva (o ping de protocolo é invisível pra ele).
      if (ws.autenticado) enviar(ws, JSON.stringify({ type: 'ping' }));
    });
  }, HEARTBEAT_MS);
  wss.on('close', () => clearInterval(intervalo));

  logger.info('🔌 WebSocket hub iniciado em /ws');
  return wss;
}

/**
 * Chamado pelo controller depois de gravar a localização no banco (PUT
 * /ordens-servico/:id/location) — empurra pro admin que estiver com o mapa
 * dessa OS aberto e/ou com a tela de acompanhamento aberta.
 *
 * Sai cedo quando não há ninguém ouvindo (caso normal: técnico em campo sem
 * admin olhando) — nem monta o JSON à toa.
 */
function broadcastPosicao(tenantId, osId, payload) {
  const setOS = assinantesPorOS.get(chaveOS(tenantId, osId));
  const setGeral = assinantesGeral.get(tenantId.toString());
  if (!setOS?.size && !setGeral?.size) return;

  const msg = JSON.stringify({ type: 'posicao', os_id: osId.toString(), ...payload });

  if (setOS) for (const ws of setOS) enviar(ws, msg);
  if (setGeral) {
    for (const ws of setGeral) {
      // Quem está nos dois (mapa aberto a partir da lista) receberia 2x.
      if (setOS && setOS.has(ws)) continue;
      enviar(ws, msg);
    }
  }
}

module.exports = { init, broadcastPosicao };
