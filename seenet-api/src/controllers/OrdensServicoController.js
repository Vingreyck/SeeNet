const { db } = require('../config/database');
const IXCService = require('../services/IXCService');

class OrdensServicoController {
  /**
   * Buscar OSs do técnico logado (pendentes e em execução)
   * GET /api/ordens-servico/minhas
   */
  async buscarMinhasOSs(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`📋 Buscando OSs do técnico ${userId} (tenant: ${tenantId})`);

      const rows = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .whereIn('os.status', ['pendente', 'em_execucao'])
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        )
        .orderByRaw(`
          CASE os.prioridade
            WHEN 'urgente' THEN 1
            WHEN 'alta' THEN 2
            WHEN 'media' THEN 3
            WHEN 'baixa' THEN 4
          END
        `)
        .orderBy('os.data_criacao', 'desc');

      console.log(`✅ ${rows.length} OS(s) encontrada(s)`);

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço',
        details: error.message
      });
    }
  }

  /**
   * ✅ NOVO: Buscar OSs concluídas do técnico
   * GET /api/ordens-servico/concluidas
   */
  async buscarOSsConcluidas(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;
      const { limite = 50, pagina = 1, busca = '' } = req.query;

      console.log(`📋 Buscando OSs concluídas do técnico ${userId}`);

      let query = db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .where('os.status', 'concluida')
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        );

      // Filtro de busca por nome do cliente
      if (busca && busca.trim() !== '') {
        query = query.whereRaw('LOWER(os.cliente_nome) LIKE ?', [`%${busca.toLowerCase()}%`]);
      }

      // Ordenar por data de conclusão (mais recentes primeiro)
      query = query.orderBy('os.data_conclusao', 'desc');

      // Paginação
      const offset = (parseInt(pagina) - 1) * parseInt(limite);
      query = query.limit(parseInt(limite)).offset(offset);

      const rows = await query;

      console.log(`✅ ${rows.length} OS(s) concluída(s) encontrada(s)`);

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs concluídas:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço concluídas',
        details: error.message
      });
    }
  }

  /**
   * Buscar detalhes de uma OS específica
   * GET /api/ordens-servico/:id/detalhes
   */
  async buscarDetalhesOS(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`🔍 Buscando detalhes da OS ${id}`);

      const os = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.id', id)
        .where('os.tenant_id', tenantId)
        .where('os.tecnico_id', userId)
        .select(
          'os.*',
          'u.nome as tecnico_nome',
          'u.email as tecnico_email'
        )
        .first();

      if (!os) {
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada ou você não tem permissão para acessá-la'
        });
      }

      // Buscar anexos
      const anexos = await db('os_anexos')
        .where('ordem_servico_id', id)
        .select('id', 'tipo', 'url_arquivo', 'nome_arquivo', 'data_upload');

      os.anexos = anexos;

      console.log(`✅ Detalhes da OS ${id} obtidos`);

      return res.json(os);
    } catch (error) {
      console.error('❌ Erro ao buscar detalhes da OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar detalhes da OS'
      });
    }
  }

/**
 * Técnico iniciou deslocamento para a OS
 * POST /api/ordens-servico/:id/deslocar
 */
async deslocarParaOS(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`🚗 Técnico deslocando para OS ${id}`);

    // Buscar OS
    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'pendente') {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS já foi iniciada' });
    }

    // Atualizar status para "em_deslocamento"
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_deslocamento',
        latitude_inicio: latitude,
        longitude_inicio: longitude,
        data_inicio_deslocamento: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    // ✅ Sincronizar deslocamento com IXC (apenas como mensagem)
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarDeslocamentoComIXC(trx, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar com IXC:', error.message);
        // Não bloqueia o deslocamento local se IXC falhar
      }
    }

    await trx.commit();

    console.log(`✅ OS ${os.numero_os} - Técnico em deslocamento`);

    return res.json({
      success: true,
      message: 'Deslocamento iniciado com sucesso'
    });
  } catch (error) {
    await trx.rollback();
    console.error('❌ Erro ao iniciar deslocamento:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar deslocamento' });
  }
}


/**
 * Sincronizar deslocamento com IXC (apenas como mensagem)
 *
 * LIMITAÇÃO DA API IXC:
 * O status "DS" (Deslocamento) só pode ser alterado pelo app "Inmap Service".
 * Não há endpoint público da API REST para mudar para este status.
 *
 * SOLUÇÃO:
 * Registramos o deslocamento como mensagem/interação no histórico da OS.
 */
async sincronizarDeslocamentoComIXC(trx, os, dados) {
  console.log(`🔄 Registrando deslocamento da OS ${os.numero_os} no IXC (como mensagem)...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const tecnico = await trx('usuarios')
    .where('id', os.tecnico_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // Formatar data/hora
  const agora = new Date();
  const dataHora = agora.toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short'
  });

  // Montar mensagem completa
  const mensagem = `🚗 DESLOCAMENTO INICIADO

Técnico: ${tecnico.nome}
Data/Hora: ${dataHora}
${dados.latitude && dados.longitude ? `Coordenadas: ${dados.latitude}, ${dados.longitude}` : ''}

Status: Técnico a caminho do local de atendimento.

📱 Registrado via SeeNet`;

  // ⚠️ Não mudamos o status (IXC não permite via API)
  // Apenas registramos como mensagem no histórico
  await ixc.adicionarMensagemOS(parseInt(os.id_externo), {
    mensagem: mensagem,
    id_tecnico: mapeamento?.tecnico_ixc_id || '',
    latitude: dados.latitude || '',
    longitude: dados.longitude || ''
  });

  console.log(`✅ OS ${os.numero_os} - Deslocamento registrado como mensagem no IXC`);
}

/**
 * Técnico chegou ao local
 * POST /api/ordens-servico/:id/chegar-local
 */
async chegarAoLocal(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`📍 Técnico chegou ao local da OS ${id}`);

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'em_deslocamento') {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS não está em deslocamento' });
    }

    // Atualizar para "em_execucao"
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_execucao',
        latitude_execucao: latitude,
        longitude_execucao: longitude,
        data_inicio: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    // Sincronizar com IXC
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarExecucaoComIXC(trx, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar execução com IXC:', error.message);
      }
    }

    await trx.commit();

    console.log(`✅ OS ${os.numero_os} em execução`);

    return res.json({
      success: true,
      message: 'Execução iniciada com sucesso'
    });
  } catch (error) {
    await trx.rollback();
    console.error('❌ Erro ao iniciar execução:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar execução' });
  }
}

/**
 * Sincronizar execução com IXC
 */
async sincronizarExecucaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando execução da OS ${os.numero_os} com IXC...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  await ixc.executarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento?.tecnico_ixc_id,
    mensagem: 'Iniciando execução do serviço',
    data_inicio: os.data_inicio_deslocamento || new Date().toISOString(),
    latitude: dados.latitude,
    longitude: dados.longitude
  });

  console.log(`✅ OS ${os.numero_os} - Status "EX" (Execução) no IXC`);
}

/**
 * Finalizar execução de OS
 * POST /api/ordens-servico/:id/finalizar
 */
async finalizarExecucao(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const tenantId = req.tenantId;
    const dados = req.body;

    console.log(`🏁 Finalizando execução da OS ${id}`);

    // 1. Buscar OS
    const os = await db('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .first();

    if (!os) {
      return res.status(404).json({
        success: false,
        error: 'OS não encontrada'
      });
    }

    if (os.status !== 'em_execucao') {
      return res.status(400).json({
        success: false,
        error: 'OS não está em execução'
      });
    }

    // 2. Atualizar dados da OS no banco
await db('ordem_servico')
  .where('id', id)
  .update({
    status: 'finalizada',
    data_conclusao: new Date(),  // ← CORRETO
    onu_modelo: dados.onu_modelo,
    onu_serial: dados.onu_serial,
    onu_status: dados.onu_status,
    onu_sinal_optico: dados.onu_sinal_optico,
    relato_problema: dados.relato_problema,
    relato_solucao: dados.relato_solucao,
    materiais_utilizados: dados.materiais_utilizados,
    observacoes: dados.observacoes,
    assinatura_cliente: dados.assinatura,
    data_atualizacao: new Date()  // ← CORRETO
  });

    // 4. Buscar mapeamento do técnico IXC
    let tecnicoIdIxc = null;
    try {
      const mapeamentoTecnico = await db('mapeamento_tecnicos_ixc')
        .where('usuario_id', os.tecnico_id)
        .where('tenant_id', tenantId)
        .first();

      tecnicoIdIxc = mapeamentoTecnico?.tecnico_ixc_id || null;
      console.log(`👤 Técnico IXC ID: ${tecnicoIdIxc || 'não mapeado'}`);
    } catch (error) {
      console.error('⚠️ Erro ao buscar mapeamento:', error.message);
    }

    // 3. Processar fotos se houver
    let fotosBase64 = [];
    if (dados.fotos && dados.fotos.length > 0) {
      console.log(`📸 Processando ${dados.fotos.length} foto(s)...`);

      // Converter fotos para base64 (se necessário)
      fotosBase64 = dados.fotos.map((foto, index) => ({
        tipo: foto.tipo || 'Foto',
        descricao: foto.descricao || `Foto ${index + 1}`,
        base64: foto.base64 || foto.data // Suporte para ambos formatos
      }));
    }

let pdfBuffer = null;
let pdfAprBase64 = null;
try {
  const AprPdfService = require('../services/AprPdfService');
  pdfBuffer = await AprPdfService.gerarPdfApr(id, tenantId);
  pdfAprBase64 = pdfBuffer.toString('base64');
  console.log(`✅ PDF APR gerado (${pdfBuffer.length} bytes)`);
} catch (aprError) {
  console.error('⚠️ Erro ao gerar PDF APR:', aprError.message);
}

// 5. Buscar configuração IXC e criar instância única
console.log('🔄 Preparando sincronização com IXC...');
let ixcService = null;
let integracao = null;

if (os.id_externo) {
  try {
    // Buscar configuração IXC
    integracao = await db('integracao_ixc')
      .where('tenant_id', tenantId)
      .where('ativo', true)
      .first();

    if (!integracao) {
      throw new Error('Integração IXC não configurada');
    }

    // Criar instância do IXCService
    ixcService = new IXCService(integracao.url_api, integracao.token_api);
    console.log('✅ Conexão IXC estabelecida');
  } catch (error) {
    console.error('⚠️ Erro ao conectar com IXC:', error.message);
  }
}

/*
// 6. Baixar PDF do IXC
console.log('📥 Baixando PDF do IXC...');
let pdfIxcBase64 = null;
if (ixcService && os.id_externo) {
  try {
    const pdfBuffer = await ixcService.baixarPdfOS(os.id_externo);
    if (pdfBuffer) {
      pdfIxcBase64 = pdfBuffer.toString('base64');
      console.log(`✅ PDF IXC baixado (${pdfBuffer.length} bytes)`);
    }
  } catch (ixcError) {
    console.error('⚠️ Erro ao baixar PDF IXC:', ixcError.message);
    // Continua sem o PDF do IXC
  }
}
*/
// 7. Sincronizar com IXC
if (ixcService && os.id_externo) {
  try {
    console.log('🔄 Sincronizando com IXC...');

    // Finalizar OS no IXC
    const mensagemFinal = `Serviço finalizado via SeeNet\n\n` +
      `PROBLEMA: ${dados.relato_problema || 'N/A'}\n` +
      `SOLUÇÃO: ${dados.relato_solucao || 'N/A'}\n` +
      `MATERIAIS: ${dados.materiais_utilizados || 'Nenhum'}\n` +
      `OBS: ${dados.observacoes || 'Nenhuma'}`;

    await ixcService.finalizarOS(os.id_externo, {
      mensagem_resposta: mensagemFinal,  // ← mensagem_resposta (conforme método espera)
      id_tecnico_ixc: tecnicoIdIxc  // ← CORRETO
    });
    console.log('✅ OS finalizada no IXC');

    // 8. Enviar itens de estoque para o IXC
    if (dados.itens_estoque && dados.itens_estoque.length > 0) {
      console.log(`📦 Enviando ${dados.itens_estoque.length} item(ns) de estoque para o IXC...`);

      const mapeamentoEstoque = await db('mapeamento_tecnicos_ixc')
        .where('usuario_id', os.tecnico_id)
        .where('tenant_id', tenantId)
        .first();

      const idAlmox = mapeamentoEstoque?.id_almoxarifado || 22;
      const hoje = new Date();
      const dataFormatada = `${String(hoje.getDate()).padStart(2,'0')}/${String(hoje.getMonth()+1).padStart(2,'0')}/${hoje.getFullYear()}`;

      for (const item of dados.itens_estoque) {
        try {
          await ixcService.adicionarProdutoOS(os.id_externo, {
            id_produto: item.id_produto,
            quantidade: item.quantidade,
            valor_unitario: item.valor_unitario,
            valor_total: item.valor_total,
            id_almox: idAlmox,
            data: dataFormatada,
            tipo_produto: item.tipo_produto || 'O',
            id_patrimonio: item.id_patrimonio || '0',
          });
          console.log(`   ✅ Item enviado: ${item.descricao} x${item.quantidade}`);
        } catch (estoqueError) {
          console.error(`   ❌ Erro ao enviar item ${item.descricao}:`, estoqueError.message);
        }
      }
    }

    // 9. Enviar fotos para o IXC
    if (fotosBase64.length > 0) {
      console.log(`📤 Enviando ${fotosBase64.length} foto(s) para o IXC...`);

      for (const foto of fotosBase64) {
        try {
          await ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
            base64: foto.base64,
            descricao: foto.descricao,
            nome: `foto_${Date.now()}.jpg`,
            ext: 'jpg'
          });
          console.log(`   ✅ ${foto.descricao} enviada`);
        } catch (fotoError) {
          console.error(`   ❌ Erro ao enviar ${foto.descricao}:`, fotoError.message);
        }
      }
    }

    // 10. Enviar PDF do APR para o IXC
    if (pdfBuffer) {
      console.log('📤 Enviando PDF do APR para o IXC...');
      try {
        await ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
          buffer: pdfBuffer,  // ← buffer direto!
          descricao: `APR - Análise Preliminar de Risco - OS ${os.numero_os}`,
          nome: `APR_OS_${os.numero_os}.pdf`,
          ext: 'pdf'
        });
        console.log('   ✅ PDF APR enviado ao IXC');
      } catch (pdfError) {
        console.error('   ❌ Erro ao enviar PDF APR:', pdfError.message);
      }
    }
  } catch (ixcError) {
    console.error('❌ Erro ao sincronizar com IXC:', ixcError.message);
    // Não retorna erro - OS foi finalizada no SeeNet
  }
}

    console.log(`✅ OS ${id} finalizada com sucesso`);

    return res.json({
      success: true,
      message: 'OS finalizada com sucesso',
      data: {
        os_id: id,
        numero_os: os.numero_os,
        status: 'finalizada',
        pdf_apr_gerado: pdfAprBase64 !== null,
        pdf_ixc_baixado: false,
        fotos_enviadas: fotosBase64.length
      }
    });

  } catch (error) {
    console.error('❌ Erro ao finalizar OS:', error);
    return res.status(500).json({
      success: false,
      error: 'Erro ao finalizar OS',
      details: error.message
    });
  }
}

  /**
   * Sincronizar finalização com IXC
   */
async sincronizarFinalizacaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando finalização da OS ${os.numero_os} com IXC...`);

  // Buscar configuração IXC
  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

// Buscar mapeamento do técnico
const mapeamentoTecnico = await db('mapeamento_tecnicos_ixc')
  .where('usuario_id', os.tecnico_id)
  .where('tenant_id', tenantId)
  .first();

const tecnicoIdIxc = mapeamentoTecnico?.tecnico_ixc_id || null;

  if (!mapeamento) {
    throw new Error('Técnico não mapeado no IXC');
  }

  // Montar mensagem completa
  let mensagemResposta = '';

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += '  RELATÓRIO DE ATENDIMENTO TÉCNICO\n';
  mensagemResposta += '═══════════════════════════════════\n\n';

  if (dados.relato_problema) {
    mensagemResposta += '📋 PROBLEMA IDENTIFICADO:\n';
    mensagemResposta += `${dados.relato_problema}\n\n`;
  }

  if (dados.relato_solucao) {
    mensagemResposta += '✅ SOLUÇÃO APLICADA:\n';
    mensagemResposta += `${dados.relato_solucao}\n\n`;
  }

  if (dados.onu_modelo || dados.onu_serial || dados.onu_status) {
    mensagemResposta += '🔧 DADOS TÉCNICOS DA ONU:\n';
    if (dados.onu_modelo) mensagemResposta += `• Modelo: ${dados.onu_modelo}\n`;
    if (dados.onu_serial) mensagemResposta += `• Serial: ${dados.onu_serial}\n`;
    if (dados.onu_status) mensagemResposta += `• Status: ${dados.onu_status}\n`;
    if (dados.onu_sinal_optico) mensagemResposta += `• Sinal Óptico: ${dados.onu_sinal_optico} dBm\n`;
    mensagemResposta += '\n';
  }

  if (dados.materiais_utilizados) {
    mensagemResposta += '🛠️ MATERIAIS UTILIZADOS:\n';
    mensagemResposta += `${dados.materiais_utilizados}\n\n`;
  }

  if (dados.observacoes) {
    mensagemResposta += '💬 OBSERVAÇÕES ADICIONAIS:\n';
    mensagemResposta += `${dados.observacoes}\n\n`;
  }

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += `📱 Atendimento via SeeNet\n`;
  mensagemResposta += '═══════════════════════════════════';

  // Criar cliente IXC
  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // 1️⃣ Finalizar OS no IXC
  await ixc.finalizarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento.tecnico_ixc_id,
    mensagem_resposta: mensagemResposta,
    latitude: os.latitude || '',
    longitude: os.longitude || '',
    data_inicio: os.data_inicio,
    data_final: new Date().toISOString()
  });

  console.log(`✅ OS ${os.numero_os} sincronizada com IXC (Finalizada)`);

// 2️⃣ Enviar fotos para IXC (se houver)
if (dados.fotos && dados.fotos.length > 0) {
  console.log(`📸 Enviando ${dados.fotos.length} foto(s) para IXC...`);

  for (let i = 0; i < dados.fotos.length; i++) {
    const fotoData = dados.fotos[i];

    try {
      // Montar descrição completa
      const labelTipo = {
        'roteador': '📡 Roteador',
        'onu': '📦 ONU',
        'local': '🏠 Local',
        'antes': '📷 Antes',
        'depois': '✅ Depois',
        'problema': '⚠️ Problema',
        'outro': '📎 Outro'
      };

      const descricaoCompleta = fotoData.descricao
        ? `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}: ${fotoData.descricao}`
        : `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}`;

      await ixc.uploadFotoOS(
        parseInt(os.id_externo),
        parseInt(os.cliente_id),
        {
          descricao: descricaoCompleta,
          base64: fotoData.base64
        }
      );

      console.log(`✅ Foto ${i + 1}/${dados.fotos.length} enviada: ${descricaoCompleta}`);
    } catch (fotoError) {
      console.error(`❌ Erro ao enviar foto ${i + 1}:`, fotoError.message);
    }
  }
}
}
/**
   * ✅ Baixar relatório PDF do IXC em background
   * Executa após finalizar a OS sem bloquear a resposta
   */
  async baixarRelatorioPDFBackground(osId, osIdExterno, tenantId) {
    try {
      console.log(`📄 Iniciando download do relatório da OS ${osIdExterno} em background...`);

      // Aguardar 5 segundos para IXC processar/gerar o relatório
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Buscar integração IXC
      const integracao = await db('integracao_ixc')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .first();

      if (!integracao) {
        throw new Error('Integração IXC não configurada');
      }

      const ixc = new IXCService(integracao.url_api, integracao.token_api);

      // Buscar e baixar relatório
      const relatorio = await ixc.buscarRelatorioPDF(osIdExterno);

      // Salvar no banco
      await db('os_anexos').insert({
        ordem_servico_id: osId,
        tipo: 'relatorio',
        descricao: relatorio.descricao,
        url_arquivo: relatorio.buffer.toString('base64'),
        nome_arquivo: relatorio.nome,
        data_upload: db.fn.now()
      });

      console.log(`✅ Relatório PDF baixado e salvo: ${relatorio.nome}`);
    } catch (error) {
      console.error(`❌ Erro ao baixar relatório da OS ${osIdExterno}:`, error.message);
      // Não propaga erro - execução em background
    }
  }
}

module.exports = new OrdensServicoController();