// src/migrations/020_create_pgr_tables.js
// Módulo PGR — Programa de Gerenciamento de Riscos (NR-1)

exports.up = async function(knex) {
  // 1. Programa principal (1 ativo por tenant, versionado)
  await knex.schema.createTable('pgr_programas', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.string('nome', 255).notNullable().defaultTo('Programa de Gerenciamento de Riscos');
    table.integer('versao').defaultTo(1);
    table.string('responsavel_nome', 255); // Quem elaborou
    table.string('responsavel_cargo', 255);
    table.string('responsavel_registro', 100); // CREA, CRT, etc.
    table.text('descricao_empresa'); // Descrição da atividade da empresa
    table.string('cnpj', 20);
    table.string('endereco', 500);
    table.string('grau_risco', 10); // 1, 2, 3 ou 4
    table.string('cnae', 20);
    table.integer('num_funcionarios');
    table.enum('status', ['rascunho', 'vigente', 'revisao', 'arquivado']).defaultTo('rascunho');
    table.date('data_elaboracao');
    table.date('data_vigencia_inicio');
    table.date('data_vigencia_fim');
    table.date('data_proxima_revisao');
    table.timestamp('data_criacao').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());

    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.index('tenant_id');
    table.index('status');
  });

  // 2. Setores / GHEs (Grupos Homogêneos de Exposição)
  await knex.schema.createTable('pgr_setores', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('programa_id').unsigned().notNullable();
    table.string('nome', 255).notNullable(); // Ex: "Técnico de Campo", "Administrativo"
    table.text('descricao'); // Descrição das atividades do setor
    table.text('ambiente_trabalho'); // Ex: "Externo — postes, caixas de emenda, residências"
    table.integer('num_trabalhadores').defaultTo(0);
    table.string('jornada', 100); // Ex: "8h diárias, seg a sáb"
    table.boolean('ativo').defaultTo(true);
    table.integer('ordem').defaultTo(0);
    table.timestamp('data_criacao').defaultTo(knex.fn.now());

    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('programa_id').references('id').inTable('pgr_programas').onDelete('CASCADE');
    table.index(['tenant_id', 'programa_id']);
  });

  // 3. Catálogo de perigos (pré-populado para telecom, extensível)
  await knex.schema.createTable('pgr_catalogo_perigos', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned(); // NULL = global (catálogo padrão telecom)
    table.string('codigo', 20); // Ex: "AC-01", "FI-01", "ER-01"
    table.enum('tipo_risco', ['acidente', 'fisico', 'quimico', 'biologico', 'ergonomico', 'psicossocial']).notNullable();
    table.string('nome', 255).notNullable(); // Ex: "Queda de altura"
    table.text('descricao'); // Detalhamento
    table.text('fonte_geradora'); // Ex: "Trabalho em postes e escadas"
    table.text('possiveis_danos'); // Ex: "Fraturas, traumatismo, óbito"
    table.string('nr_referencia', 100); // Ex: "NR-35"
    table.boolean('ativo').defaultTo(true);
    table.timestamp('data_criacao').defaultTo(knex.fn.now());

    table.index('tenant_id');
    table.index('tipo_risco');
  });

  // 4. Inventário de Riscos (coração do PGR)
  await knex.schema.createTable('pgr_inventario_riscos', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('programa_id').unsigned().notNullable();
    table.integer('setor_id').unsigned().notNullable();
    table.integer('perigo_id').unsigned(); // Ref ao catálogo (opcional, pode ser manual)
    table.string('perigo_descricao', 500).notNullable(); // Descrição do perigo
    table.enum('tipo_risco', ['acidente', 'fisico', 'quimico', 'biologico', 'ergonomico', 'psicossocial']).notNullable();
    table.text('fonte_geradora');
    table.text('possiveis_danos');
    table.integer('num_expostos').defaultTo(0);
    // Matriz de Risco 5x5
    table.integer('probabilidade').notNullable().defaultTo(1); // 1=Rara, 2=Improvável, 3=Possível, 4=Provável, 5=Quase certa
    table.integer('severidade').notNullable().defaultTo(1); // 1=Insignificante, 2=Leve, 3=Moderado, 4=Grave, 5=Catastrófico
    table.integer('nivel_risco'); // probabilidade × severidade (calculado)
    table.enum('classificacao_risco', ['trivial', 'toleravel', 'moderado', 'substancial', 'intoleravel']);
    // Medidas existentes
    table.text('medidas_existentes'); // O que já está sendo feito
    table.text('epis_recomendados'); // JSON array de EPIs
    table.text('epcs_recomendados'); // JSON array de EPCs
    table.string('nr_referencia', 100);
    table.boolean('ativo').defaultTo(true);
    table.timestamp('data_identificacao').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());

    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('programa_id').references('id').inTable('pgr_programas').onDelete('CASCADE');
    table.foreign('setor_id').references('id').inTable('pgr_setores').onDelete('CASCADE');
    table.foreign('perigo_id').references('id').inTable('pgr_catalogo_perigos').onDelete('SET NULL');
    table.index(['tenant_id', 'programa_id']);
    table.index(['setor_id']);
    table.index('classificacao_risco');
  });

  // 5. Plano de Ação
  await knex.schema.createTable('pgr_plano_acao', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('programa_id').unsigned().notNullable();
    table.integer('risco_id').unsigned().notNullable(); // Vinculado ao inventário
    table.text('acao').notNullable(); // O que será feito
    table.enum('tipo_medida', ['eliminacao', 'substituicao', 'engenharia', 'administrativa', 'epc', 'epi']).notNullable();
    table.string('responsavel_nome', 255);
    table.integer('responsavel_id').unsigned(); // Ref usuario
    table.date('prazo');
    table.enum('status', ['pendente', 'em_andamento', 'concluida', 'cancelada']).defaultTo('pendente');
    table.enum('prioridade', ['baixa', 'media', 'alta', 'urgente']).defaultTo('media');
    table.text('evidencia'); // Descrição da evidência de conclusão
    table.text('evidencia_foto_base64'); // Foto comprovando
    table.date('data_conclusao');
    table.text('observacoes');
    table.timestamp('data_criacao').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());

    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('programa_id').references('id').inTable('pgr_programas').onDelete('CASCADE');
    table.foreign('risco_id').references('id').inTable('pgr_inventario_riscos').onDelete('CASCADE');
    table.index(['tenant_id', 'programa_id']);
    table.index('status');
    table.index('prazo');
  });

  // 6. Histórico de revisões (obrigatório NR-1: manter 20 anos)
  await knex.schema.createTable('pgr_revisoes', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('programa_id').unsigned().notNullable();
    table.integer('versao').notNullable();
    table.enum('motivo', [
      'revisao_periodica',      // Revisão bienal obrigatória
      'mudanca_processo',       // Mudança em processos/tecnologias
      'acidente_trabalho',      // Após acidente ou doença ocupacional
      'medida_ineficaz',        // Medida de prevenção inadequada
      'mudanca_legislacao',     // Alteração em NRs aplicáveis
      'outro'
    ]).notNullable();
    table.text('descricao'); // O que mudou
    table.string('responsavel_nome', 255);
    table.text('snapshot_json'); // Snapshot completo do PGR naquele momento
    table.timestamp('data_revisao').defaultTo(knex.fn.now());

    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('programa_id').references('id').inTable('pgr_programas').onDelete('CASCADE');
    table.index(['tenant_id', 'programa_id']);
  });
};

exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('pgr_revisoes');
  await knex.schema.dropTableIfExists('pgr_plano_acao');
  await knex.schema.dropTableIfExists('pgr_inventario_riscos');
  await knex.schema.dropTableIfExists('pgr_catalogo_perigos');
  await knex.schema.dropTableIfExists('pgr_setores');
  await knex.schema.dropTableIfExists('pgr_programas');
};