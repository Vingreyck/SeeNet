// src/services/AprPdfService.js
const PDFDocument = require('pdfkit');
const { db } = require('../config/database');

class AprPdfService {

  /**
   * Gera PDF do APR para uma OS
   * @param {number} osId
   * @param {number} tenantId
   * @returns {Promise<Buffer>} Buffer do PDF
   */
  static async gerarPdfApr(osId, tenantId) {
    try {
      // 1. Buscar dados da OS + técnico
      const os = await db('ordem_servico as o')
        .join('usuarios as u', 'u.id', 'o.tecnico_id')
        .where('o.id', osId)
        .where('o.tenant_id', tenantId)
        .select('o.*', 'u.nome as tecnico_nome')
        .first();

      if (!os) {
        throw new Error('OS não encontrada');
      }

      // 2. Buscar respostas do APR
      const respostas = await db.raw(`
        SELECT
          c.id as categoria_id,
          c.nome as categoria_nome,
          c.ordem as categoria_ordem,
          p.id as pergunta_id,
          p.pergunta,
          p.tipo_resposta,
          r.resposta,
          r.justificativa,
          r.data_resposta
        FROM respostas_apr r
        INNER JOIN checklist_perguntas_apr p ON p.id = r.pergunta_id
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE r.ordem_servico_id = ?
        ORDER BY c.ordem, p.ordem
      `, [osId]);

      if (respostas.rows.length === 0) {
        throw new Error('APR não preenchido para esta OS');
      }

      // 3. Buscar EPIs selecionados
      const epis = await db.raw(`
        SELECT o.opcao
        FROM respostas_apr_epis re
        INNER JOIN checklist_opcoes_apr o ON o.id = re.opcao_id
        INNER JOIN respostas_apr r ON r.id = re.resposta_apr_id
        WHERE r.ordem_servico_id = ?
        ORDER BY o.ordem
      `, [osId]);

      // 4. Buscar assinatura do técnico
      const assinaturaObj = await db('ordem_servico')
        .where('id', osId)
        .select('assinatura_cliente')
        .first();

      // 5. Organizar respostas por categoria
      const categorias = {};
      respostas.rows.forEach(r => {
        if (!categorias[r.categoria_id]) {
          categorias[r.categoria_id] = {
            nome: r.categoria_nome,
            ordem: r.categoria_ordem,
            perguntas: []
          };
        }
        categorias[r.categoria_id].perguntas.push({
          pergunta: r.pergunta,
          tipo: r.tipo_resposta,
          resposta: r.resposta,
          justificativa: r.justificativa
        });
      });

      // 6. Gerar PDF
      return await this._criarPdf(os, categorias, epis.rows, assinaturaObj?.assinatura_cliente);

    } catch (error) {
      console.error('❌ Erro ao gerar PDF APR:', error);
      throw error;
    }
  }

  /**
   * Cria o PDF usando pdfkit
   */
  static async _criarPdf(os, categorias, epis, assinaturaBase64 = null) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({
          size: 'A4',
          margins: { top: 50, bottom: 50, left: 50, right: 50 }
        });

        const chunks = [];
        doc.on('data', chunk => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // === CABEÇALHO ===
        doc.fontSize(20).font('Helvetica-Bold')
           .fillColor('#D32F2F')
           .text('APR - ANÁLISE PRELIMINAR DE RISCO', { align: 'center' });

        doc.moveDown(0.5);
        doc.fontSize(12).fillColor('#000000')
           .text('BBnet Up Telecomunicações', { align: 'center' });

        doc.moveDown(0.3);
        doc.fontSize(10).fillColor('#666666')
           .text(`OS #${os.numero_os} | Protocolo IXC: ${os.protocolo_ixc || 'N/A'}`, { align: 'center' })
           .text(`Data: ${new Date(os.data_criacao).toLocaleDateString('pt-BR')}`, { align: 'center' });

        doc.moveDown(1);
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke('#CCCCCC');
        doc.moveDown(0.5);

        // === DADOS DO ATENDIMENTO ===
        doc.fontSize(14).font('Helvetica-Bold').fillColor('#000000')
           .text('DADOS DO ATENDIMENTO');
        doc.moveDown(0.3);

        doc.fontSize(10).font('Helvetica').fillColor('#333333');
        const dadosY = doc.y;

        doc.text(`Cliente: ${os.cliente_nome || 'N/A'}`, 50, dadosY);
        doc.text(`Endereço: ${os.cliente_endereco || 'N/A'}`, 50, dadosY + 15);
        doc.text(`Técnico: ${os.tecnico_nome || 'N/A'}`, 50, dadosY + 30);

        doc.moveDown(3);
        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke('#CCCCCC');
        doc.moveDown(0.5);

        // === RESPOSTAS POR CATEGORIA ===
        const categoriasOrdenadas = Object.values(categorias).sort((a, b) => a.ordem - b.ordem);

        categoriasOrdenadas.forEach((cat, catIndex) => {
          // Título da categoria
          doc.fontSize(12).font('Helvetica-Bold').fillColor('#007700')
             .text(`${cat.ordem}. ${cat.nome.toUpperCase()}`);
          doc.moveDown(0.3);

          // Perguntas
          cat.perguntas.forEach((perg, pergIndex) => {
            // Verifica se precisa de nova página
            if (doc.y > 700) {
              doc.addPage();
            }

            doc.fontSize(10).font('Helvetica').fillColor('#000000');

            // Pergunta
            doc.text(`${catIndex + 1}.${pergIndex + 1}. ${perg.pergunta}`, {
              width: 495,
              continued: false
            });

            // Resposta
            if (perg.tipo === 'sim_nao') {
              const cor = perg.resposta === 'SIM' ? '#00AA00' : '#FF0000';
              doc.fontSize(10).font('Helvetica-Bold').fillColor(cor)
                 .text(`   ➤ ${perg.resposta}`, { indent: 20 });

              if (perg.justificativa) {
                doc.fontSize(9).font('Helvetica-Oblique').fillColor('#666666')
                   .text(`   Justificativa: ${perg.justificativa}`, { indent: 30 });
              }
            } else if (perg.tipo === 'texto') {
              doc.fontSize(10).font('Helvetica').fillColor('#333333')
                 .text(`   ➤ ${perg.resposta}`, { indent: 20 });
            }

            doc.moveDown(0.4);
          });

          doc.moveDown(0.5);
        });

        // === EPIs SELECIONADOS ===
        if (epis.length > 0) {
          if (doc.y > 650) doc.addPage();

          doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke('#CCCCCC');
          doc.moveDown(0.5);

          doc.fontSize(12).font('Helvetica-Bold').fillColor('#007700')
             .text('EQUIPAMENTOS DE PROTEÇÃO UTILIZADOS');
          doc.moveDown(0.3);

          doc.fontSize(10).font('Helvetica').fillColor('#000000');
          epis.forEach(epi => {
            doc.text(`✓ ${epi.opcao}`, { indent: 20 });
          });

          doc.moveDown(1);
        }

        // === TERMO DE RESPONSABILIDADE ===
        if (doc.y > 620) doc.addPage();

        doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke('#CCCCCC');
        doc.moveDown(0.5);

        doc.fontSize(12).font('Helvetica-Bold').fillColor('#D32F2F')
           .text('TERMO DE RESPONSABILIDADE');
        doc.moveDown(0.3);

        doc.fontSize(9).font('Helvetica').fillColor('#333333')
           .text(
             'Declaro que as informações acima são verdadeiras e que me responsabilizo pela execução segura deste serviço, ' +
             'atendendo às Normas Regulamentadoras NR-10 e NR-35, conforme legislação vigente.',
             { align: 'justify', width: 495 }
           );

        doc.moveDown(2);

        // === RODAPÉ COM ASSINATURAS ===
        const finalY = doc.y + 20;

        // Assinatura do técnico (imagem se houver)
        if (assinaturaBase64) {
          try {
            const assinaturaBuffer = Buffer.from(assinaturaBase64, 'base64');
            doc.image(assinaturaBuffer, 55, finalY - 45, { width: 150, height: 40 });
          } catch (e) {
            console.error('⚠️ Erro ao inserir assinatura:', e.message);
          }
        }

        // Linha + nome do técnico
        doc.fontSize(8).fillColor('#666666')
           .text('_____________________________', 50, finalY, { width: 200, align: 'center' })
           .text(`${os.tecnico_nome || 'Colaborador Responsável'}`, 50, finalY + 12, { width: 200, align: 'center' })
           .text('Colaborador Responsável', 50, finalY + 22, { width: 200, align: 'center' });

        // Linha + cliente
        doc.fontSize(8).fillColor('#666666')
           .text('_____________________________', 345, finalY, { width: 200, align: 'center' })
           .text(`${os.cliente_nome || 'Cliente'}`, 345, finalY + 12, { width: 200, align: 'center' })
           .text('Cliente', 345, finalY + 22, { width: 200, align: 'center' });

        // Footer
        doc.fontSize(8).fillColor('#999999')
           .text(
             `Documento gerado em ${new Date().toLocaleString('pt-BR')} | SeeNet - Sistema de Gestão`,
             50, 750,
             { width: 495, align: 'center' }
           );

        doc.end();

      } catch (error) {
        reject(error);
      }
    });
  }
}

module.exports = AprPdfService;