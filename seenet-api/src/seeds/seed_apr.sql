-- =====================================================
-- SEED APR - ANÁLISE PRELIMINAR DE RISCO
-- Sistema: SeeNet
-- Data: 2026-02-11
-- =====================================================

-- Limpar dados existentes
DELETE FROM respostas_apr_epis;
DELETE FROM respostas_apr;
DELETE FROM checklist_opcoes_apr;
DELETE FROM checklist_perguntas_apr;
DELETE FROM checklist_categorias_apr;

-- Reset sequences
ALTER SEQUENCE checklist_categorias_apr_id_seq RESTART WITH 1;
ALTER SEQUENCE checklist_perguntas_apr_id_seq RESTART WITH 1;
ALTER SEQUENCE checklist_opcoes_apr_id_seq RESTART WITH 1;

-- =====================================================
-- CATEGORIAS
-- =====================================================
INSERT INTO checklist_categorias_apr (tenant_id, nome, ordem, ativo) VALUES
(NULL, 'Condições da Equipe', 1, true),
(NULL, 'Equipamentos e Condições', 2, true),
(NULL, 'Análise de Riscos', 3, true),
(NULL, 'EPIs e EPCs', 4, true),
(NULL, 'Conclusão', 5, true);

-- =====================================================
-- CATEGORIA 1: Condições da Equipe (6 perguntas)
-- =====================================================
INSERT INTO checklist_perguntas_apr (categoria_id, pergunta, tipo_resposta, obrigatorio, requer_justificativa_se, ordem, ativo) VALUES
(1, 'Todos os componentes da equipe foram informados sobre o tipo de serviço que será executado?', 'sim_nao', true, 'nao', 1, true),
(1, 'Todos os componentes da equipe estão em boas condições físicas e psicológicas para executar a tarefa?', 'sim_nao', true, 'nao', 2, true),
(1, 'Os componentes da equipe estão SEM adornos (correntes, anéis, brincos, piercings)?', 'sim_nao', true, 'nao', 3, true),
(1, 'Os membros da equipe estão aptos para participar de resgate em caso de emergência?', 'sim_nao', true, 'nao', 4, true),
(1, 'Os componentes da equipe conhecem o local de atendimento hospitalar mais próximo?', 'sim_nao', true, 'nao', 5, true),
(1, 'Os componentes da equipe estão com os treinamentos obrigatórios em dia (NR-10, NR-35)?', 'sim_nao', true, 'nao', 6, true);

-- =====================================================
-- CATEGORIA 2: Equipamentos e Condições (7 perguntas)
-- =====================================================
INSERT INTO checklist_perguntas_apr (categoria_id, pergunta, tipo_resposta, obrigatorio, requer_justificativa_se, ordem, ativo) VALUES
(2, 'O veículo utilizado pela equipe está em boas condições de uso?', 'sim_nao', true, 'nao', 1, true),
(2, 'As condições climáticas estão favoráveis para execução do serviço?', 'sim_nao', true, 'nao', 2, true),
(2, 'É possível amarrar a escada em local seguro?', 'sim_nao', true, 'nao', 3, true),
(2, 'A escada está em boas condições de uso (sem rachaduras, degraus soltos ou amassados)?', 'sim_nao', true, 'nao', 4, true),
(2, 'Existe algum impedimento para a realização do serviço no local?', 'sim_nao', true, 'sim', 5, true),
(2, 'As ferramentas e equipamentos estão em boas condições de uso?', 'sim_nao', true, 'nao', 6, true),
(2, 'Existem condições climáticas adversas (chuva, vento forte, tempestade)?', 'sim_nao', true, 'sim', 7, true);

-- =====================================================
-- CATEGORIA 3: Análise de Riscos (8 perguntas)
-- =====================================================
INSERT INTO checklist_perguntas_apr (categoria_id, pergunta, tipo_resposta, obrigatorio, requer_justificativa_se, ordem, ativo) VALUES
(3, 'Existe risco de atropelamento ou colisão com veículos?', 'sim_nao', true, NULL, 1, true),
(3, 'Existe circulação de pessoas não autorizadas no local?', 'sim_nao', true, NULL, 2, true),
(3, 'Existe possibilidade de presença de animais peçonhentos?', 'sim_nao', true, NULL, 3, true),
(3, 'Existe risco ergonômico (postura inadequada, esforço físico intenso)?', 'sim_nao', true, NULL, 4, true),
(3, 'O trabalho será realizado em altura superior a 2 metros?', 'sim_nao', true, NULL, 5, true),
(3, 'Existe risco de queda de objetos ou ferramentas?', 'sim_nao', true, NULL, 6, true),
(3, 'Existe risco de choque elétrico?', 'sim_nao', true, NULL, 7, true),
(3, 'Existe risco de exposição à radiação não ionizante (antenas, rádio frequência)?', 'sim_nao', true, NULL, 8, true);

-- =====================================================
-- CATEGORIA 4: EPIs e EPCs (1 pergunta com 10 opções)
-- =====================================================
INSERT INTO checklist_perguntas_apr (categoria_id, pergunta, tipo_resposta, obrigatorio, requer_justificativa_se, ordem, ativo) VALUES
(4, 'Selecione os Equipamentos de Proteção Individual (EPIs) e Coletiva (EPCs) que serão utilizados:', 'multipla_escolha', true, NULL, 1, true);

-- Opções de EPIs/EPCs
INSERT INTO checklist_opcoes_apr (pergunta_id, opcao, ordem) VALUES
(22, 'Capacete de segurança (Classe B)', 1),
(22, 'Carneira e jugular', 2),
(22, 'Balaclava (proteção de pescoço e nuca)', 3),
(22, 'Óculos de segurança', 4),
(22, 'Luva isolante de borracha', 5),
(22, 'Cinto de segurança tipo paraquedista', 6),
(22, 'Detector de tensão', 7),
(22, 'Cones de sinalização', 8),
(22, 'Fita zebrada de isolamento', 9),
(22, 'Luva de vaqueta', 10);

-- =====================================================
-- CATEGORIA 5: Conclusão (5 perguntas)
-- =====================================================
INSERT INTO checklist_perguntas_apr (categoria_id, pergunta, tipo_resposta, obrigatorio, requer_justificativa_se, ordem, ativo) VALUES
(5, 'Com base nas condições analisadas, o serviço pode ser realizado com segurança?', 'sim_nao', true, 'nao', 1, true),
(5, 'Nome do colaborador responsável 1:', 'texto', true, NULL, 2, true),
(5, 'Nome do colaborador responsável 2 (opcional):', 'texto', false, NULL, 3, true),
(5, 'Nome do colaborador responsável 3 (opcional):', 'texto', false, NULL, 4, true),
(5, 'Nome do colaborador responsável 4 (opcional):', 'texto', false, NULL, 5, true);

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================
SELECT
  'Categorias' as tabela,
  COUNT(*) as total
FROM checklist_categorias_apr
WHERE ativo = true

UNION ALL

SELECT
  'Perguntas' as tabela,
  COUNT(*) as total
FROM checklist_perguntas_apr
WHERE ativo = true

UNION ALL

SELECT
  'Opções (EPIs)' as tabela,
  COUNT(*) as total
FROM checklist_opcoes_apr;

-- =====================================================
-- FIM DO SEED
-- =====================================================