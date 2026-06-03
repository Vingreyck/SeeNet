// src/services/NotificationService.js
const admin = require('firebase-admin');

class NotificationService {
  constructor() {
    this._initialized = false;
    this._init();
  }

  _init() {
    try {
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (!serviceAccountJson) {
        console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT não configurada — push notifications desabilitadas');
        return;
      }

      const serviceAccount = JSON.parse(serviceAccountJson);

      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }

      this._initialized = true;
      console.log('✅ Firebase Admin SDK inicializado');
    } catch (error) {
      console.error('❌ Erro ao inicializar Firebase Admin:', error.message);
    }
  }

  async enviarPush(fcmToken, titulo, corpo, data = {}) {
    if (!this._initialized) {
      console.warn('⚠️ Firebase não inicializado — push não enviado');
      return false;
    }

    if (!fcmToken) {
      console.warn('⚠️ FCM token vazio — push não enviado');
      return false;
    }

    try {
      const message = {
        token: fcmToken,
        notification: { title: titulo, body: corpo },
        data: {
          ...Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'seenet_notifications',
            priority: 'high',
            defaultSound: true,
          },
        },
      };

      await admin.messaging().send(message);
      console.log(`✅ Push enviado: "${titulo}" → ${fcmToken.substring(0, 20)}...`);
      return true;
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        console.warn(`⚠️ FCM token inválido: ${fcmToken.substring(0, 20)}...`);
      } else {
        console.error('❌ Erro ao enviar push:', error.message);
      }
      return false;
    }
  }

  /**
   * Grava a notificação na tabela `notificacoes` (histórico/sininho do app).
   * Best-effort: nunca lança erro (não atrapalha o envio do push).
   * Grava para uma lista de usuários de uma vez (um INSERT só).
   */
  async _salvarHistorico(db, tenantId, usuarioIds, titulo, corpo, data = {}) {
    if (!tenantId || !usuarioIds || usuarioIds.length === 0) return;
    // referencia_id é INTEGER no banco; o push manda como texto. Converte com segurança.
    const refNum = parseInt(data.referencia_id, 10);
    const linhas = usuarioIds.map((uid) => ({
      tenant_id: tenantId,
      usuario_id: uid,
      titulo,
      corpo: corpo || null,
      tipo: data.tipo || null,
      referencia_id: Number.isNaN(refNum) ? null : refNum,
    }));
    try {
      await db('notificacoes').insert(linhas);
    } catch (e) {
      console.warn('⚠️ Falha ao salvar histórico de notificação:', e.message);
    }
  }

  async enviarParaUsuario(db, usuarioId, titulo, corpo, data = {}) {
    try {
      const usuario = await db('usuarios')
        .where('id', usuarioId)
        .select('fcm_token', 'nome', 'tenant_id')
        .first();

      if (!usuario) {
        console.warn(`⚠️ Usuário ${usuarioId} não encontrado`);
        return false;
      }

      // Salva no histórico SEMPRE (mesmo sem token) — aparece no sininho do app.
      await this._salvarHistorico(db, usuario.tenant_id, [usuarioId], titulo, corpo, data);

      if (!usuario.fcm_token) {
        console.warn(`⚠️ Usuário ${usuarioId} sem FCM token`);
        return false;
      }

      return await this.enviarPush(usuario.fcm_token, titulo, corpo, data);
    } catch (error) {
      console.error(`❌ Erro ao enviar para usuário ${usuarioId}:`, error.message);
      return false;
    }
  }

  /**
   * Notificar técnico de nova OS atribuída
   */
  async notificarNovaOS(db, tecnicoId, numeroOs, clienteNome) {
    return await this.enviarParaUsuario(
      db,
      tecnicoId,
      '📋 Nova Ordem de Serviço',
      `OS #${numeroOs} - ${clienteNome} foi atribuída a você.`,
      { route: '/ordens-servico', tipo: 'nova_os' }
    );
  }

  /**
   * Envia o MESMO push para VÁRIOS usuários de uma vez (em lote), usando o
   * multicast do FCM (sendEachForMulticast). Muito mais rápido que enviar um a
   * um: 50 pessoas saem em 1 chamada em vez de 50 sequenciais.
   * Também limpa do banco os tokens que o FCM reportar como definitivamente
   * inválidos (celular trocado / app desinstalado).
   *
   * @param usuarios lista já filtrada, cada item com { id, fcm_token }
   * @returns quantidade de pushes entregues com sucesso
   */
  async _enviarEmMassa(db, usuarios, titulo, corpo, data = {}) {
    if (!this._initialized) {
      console.warn('⚠️ Firebase não inicializado — push não enviado');
      return 0;
    }

    const alvos = (usuarios || []).filter(u => u.fcm_token);
    if (alvos.length === 0) return 0;

    const dataStr = {
      ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    };
    const android = {
      priority: 'high',
      notification: {
        channelId: 'seenet_notifications',
        priority: 'high',
        defaultSound: true,
      },
    };

    let enviados = 0;
    const idsTokenInvalido = [];

    // FCM aceita até 500 tokens por chamada — fatiamos por segurança.
    for (let i = 0; i < alvos.length; i += 500) {
      const lote = alvos.slice(i, i + 500);
      try {
        const resp = await admin.messaging().sendEachForMulticast({
          tokens: lote.map(u => u.fcm_token),
          notification: { title: titulo, body: corpo },
          data: dataStr,
          android,
        });
        enviados += resp.successCount;
        resp.responses.forEach((r, idx) => {
          if (!r.success) {
            const code = r.error?.code;
            if (code === 'messaging/registration-token-not-registered' ||
                code === 'messaging/invalid-registration-token' ||
                code === 'messaging/invalid-argument') {
              idsTokenInvalido.push(lote[idx].id);
            }
          }
        });
      } catch (error) {
        console.error('❌ Erro ao enviar push em massa:', error.message);
      }
    }

    // Limpeza best-effort dos tokens inválidos (não trava o envio se falhar).
    if (idsTokenInvalido.length > 0) {
      try {
        await db('usuarios').whereIn('id', idsTokenInvalido).update({ fcm_token: null });
        console.log(`🧹 ${idsTokenInvalido.length} token(s) FCM inválido(s) limpo(s)`);
      } catch (e) {
        console.warn('⚠️ Falha ao limpar tokens inválidos:', e.message);
      }
    }

    return enviados;
  }

  /**
   * Envia push APENAS para gestores de segurança (NÃO inclui administradores)
   */
  async enviarParaGestores(db, tenantId, titulo, corpo, data = {}) {
    try {
      const gestores = await db('usuarios')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .where('tipo_usuario', 'gestor_seguranca')  // ✅ SÓ GESTOR DE SEGURANÇA
        .select('id', 'fcm_token', 'nome');

      // Histórico para todos os gestores (mesmo sem token); push só pra quem tem.
      await this._salvarHistorico(db, tenantId, gestores.map(g => g.id), titulo, corpo, data);

      const enviados = await this._enviarEmMassa(db, gestores, titulo, corpo, data);
      console.log(`📤 Push enviado para ${enviados}/${gestores.length} gestores de segurança`);
      return enviados;
    } catch (error) {
      console.error('❌ Erro ao enviar para gestores:', error.message);
      return 0;
    }
  }

  async enviarParaTodos(db, tenantId, titulo, corpo, data = {}) {
    try {
      const usuarios = await db('usuarios')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .select('id', 'fcm_token', 'nome');

      // Histórico para todos os usuários (mesmo sem token); push só pra quem tem.
      await this._salvarHistorico(db, tenantId, usuarios.map(u => u.id), titulo, corpo, data);

      const enviados = await this._enviarEmMassa(db, usuarios, titulo, corpo, data);
      console.log(`📤 Push DDS: ${enviados}/${usuarios.length} usuários notificados`);
      return enviados;
    } catch (error) {
      console.error('❌ Erro ao enviar para todos:', error.message);
      return 0;
    }
  }
}

module.exports = new NotificationService();