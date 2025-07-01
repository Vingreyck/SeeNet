-- Script para verificar e corrigir o banco SeeNet
USE seenet;

-- ========== VERIFICAR ESTADO ATUAL ==========
SELECT 'VERIFICAÇÃO DO BANCO' as info;

-- Verificar usuários existentes
SELECT 'Usuários existentes:' as info;
SELECT id, nome, email, tipo_usuario, ativo FROM usuarios;

-- Verificar categorias existentes
SELECT 'Categorias existentes:' as info;
SELECT id, nome, descricao, ordem FROM categorias_checkmark;

-- Verificar checkmarks existentes
SELECT 'Checkmarks existentes:' as info;
SELECT COUNT(*) as total_checkmarks FROM checkmarks;

-- ========== CORRIGIR USUÁRIOS ==========
-- Deletar usuário admin existente (se necessário)
DELETE FROM usuarios;

-- Inserir usuários corretos
INSERT INTO usuarios (nome, email, senha, tipo_usuario) VALUES 
('Administrador', 'admin@seenet.com', SHA2('admin123', 256), 'administrador'),
('Técnico Teste', 'tecnico@seenet.com', SHA2('123456', 256), 'tecnico');

-- ========== VERIFICAR SE CATEGORIAS EXISTEM ==========
-- Se não existir, inserir categorias
DELETE FROM checkmarks;
DELETE FROM categorias_checkmark;

INSERT INTO categorias_checkmark (nome, descricao, ordem) VALUES 
('Lentidão', 'Problemas de velocidade, buffering e lentidão geral', 1),
('IPTV', 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', 2),
('Aplicativos', 'Apps não carregam, erro de carregamento da logo', 3),
('Acesso Remoto', 'Ativação de acessos remotos dos roteadores', 4);

-- ========== VERIFICAR SE CHECKMARKS EXISTEM ==========
-- Limpar checkmarks existentes (se houver)
DELETE FROM checkmarks;

-- Inserir checkmarks para LENTIDÃO (categoria_id = 1)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES 
(1, 'Velocidade abaixo do contratado', 'Cliente relata velocidade de internet abaixo do contratado', 'Analise um problema de lentidão onde o cliente relata velocidade abaixo do contratado. Forneça um diagnóstico técnico e soluções práticas.', 1),
(1, 'Lentidão alta ping > 100ms', 'Ping alto acima de 100ms causando travamentos', 'Cliente apresenta ping alto acima de 100ms. Analise as possíveis causas e forneça soluções para reduzir a latência.', 2),
(1, 'Perda de pacotes', 'Perda de pacotes na conexão', 'Diagnóstico para problema de perda de pacotes na conexão de internet. Identifique causas e soluções.', 3),
(1, 'Problemas no cabo', 'Problemas físicos no cabeamento', 'Analise problemas relacionados ao cabeamento de rede e forneça orientações para resolução.', 4),
(1, 'Wi-Fi com sinal fraco', 'Sinal WiFi fraco ou instável', 'Cliente relata sinal WiFi fraco. Forneça diagnóstico e soluções para melhorar a cobertura wireless.', 5),
(1, 'Roteador com defeito', 'Equipamento apresentando falhas', 'Possível defeito no roteador. Diagnóstico e verificações necessárias.', 6),
(1, 'Muitos dispositivos conectados', 'Sobrecarga na rede por excesso de dispositivos', 'Rede sobrecarregada por muitos dispositivos conectados simultaneamente.', 7),
(1, 'Interferência eletromagnética', 'Interferência afetando o sinal', 'Interferência de outros equipamentos afetando a qualidade da conexão.', 8);

-- Inserir checkmarks para IPTV (categoria_id = 2)  
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES 
(2, 'Canais travando/congelando', 'Canais de TV travando ou congelando', 'Problemas de travamento nos canais de IPTV. Analise e forneça soluções técnicas.', 1),
(2, 'Buffering constante', 'Buffering constante nos canais', 'IPTV apresenta buffering constante. Diagnóstico e soluções para melhorar a qualidade.', 2),
(2, 'Canal fora do ar', 'Canais específicos fora do ar', 'Canais de IPTV fora do ar. Analise possíveis causas e soluções.', 3),
(2, 'Qualidade baixa', 'Qualidade de vídeo baixa', 'Qualidade de vídeo ruim no IPTV. Forneça diagnóstico e melhorias.', 4),
(2, 'IPTV não abre', 'Aplicativo IPTV não abre', 'IPTV não consegue abrir ou inicializar. Diagnóstico e soluções.', 5),
(2, 'Erro de autenticação', 'Problemas de login no IPTV', 'Erros de autenticação no IPTV. Analise e forneça soluções.', 6),
(2, 'Audio dessincronizado', 'Audio fora de sincronia com vídeo', 'Problemas de sincronização entre audio e vídeo no IPTV.', 7),
(2, 'Demora para carregar', 'Lentidão para iniciar canais', 'Canais demoram muito para carregar ou inicializar.', 8);

-- Inserir checkmarks para APLICATIVOS (categoria_id = 3)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES 
(3, 'Aplicativo não abre', 'Apps não conseguem abrir', 'Aplicativos não abrem. Diagnóstico e soluções.', 1),
(3, 'Erro de conexão', 'Apps apresentam erro de conexão', 'Aplicativos com erro de conexão. Analise e solucione.', 2),
(3, 'Buffering constante', 'Apps com buffering constante', 'Aplicativos apresentam buffering constante. Diagnóstico e soluções.', 3),
(3, 'Qualidade baixa', 'Qualidade baixa nos aplicativos', 'Qualidade de streaming baixa nos apps. Diagnóstico e melhorias.', 4),
(3, 'Error code: xxxxx', 'Códigos de erro específicos', 'Aplicativo apresenta códigos de erro. Analise e forneça soluções baseadas no código.', 5),
(3, 'App trava constantemente', 'Aplicativo trava durante uso', 'Aplicativo para de responder ou trava durante o uso.', 6),
(3, 'Login não funciona', 'Problemas de autenticação nos apps', 'Não consegue fazer login nos aplicativos.', 7),
(3, 'Conteúdo não carrega', 'Conteúdo dos apps não carrega', 'Aplicativos abrem mas o conteúdo não carrega.', 8);

-- Inserir checkmarks para ACESSO REMOTO (categoria_id = 4)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES 
(4, 'TP-link WR940N', 'Configuração de acesso remoto TP-link WR940N', 'Configure acesso remoto para roteador TP-link WR940N. Forneça passo a passo técnico.', 1),
(4, 'MULTILASER 1200AC', 'Configuração MULTILASER 1200AC', 'Configure acesso remoto para roteador MULTILASER 1200AC. Guia técnico completo.', 2),
(4, 'Intelbras Action RF1200', 'Configuração Intelbras RF1200', 'Setup de acesso remoto para Intelbras Action RF1200. Procedimentos técnicos.', 3),
(4, 'Mercusys MW325R', 'Configuração Mercusys MW325R', 'Acesso remoto Mercusys MW325R. Configurações avançadas.', 4),
(4, 'Tenda AC10', 'Configuração Tenda AC10', 'Setup remoto para Tenda AC10. Instruções detalhadas.', 5),
(4, 'D-Link DIR-615', 'Configuração D-Link DIR-615', 'Configuração de acesso remoto D-Link DIR-615. Guia completo.', 6);

-- ========== VERIFICAÇÃO FINAL ==========
SELECT 'VERIFICAÇÃO FINAL:' as info;

-- Contar registros
SELECT 'Usuários cadastrados:' as tipo, COUNT(*) as quantidade FROM usuarios;
SELECT 'Categorias cadastradas:' as tipo, COUNT(*) as quantidade FROM categorias_checkmark;
SELECT 'Checkmarks cadastrados:' as tipo, COUNT(*) as quantidade FROM checkmarks;

-- Mostrar estrutura criada
SELECT 
    c.nome as categoria, 
    COUNT(ch.id) as total_checkmarks 
FROM categorias_checkmark c 
LEFT JOIN checkmarks ch ON c.id = ch.categoria_id 
GROUP BY c.id, c.nome 
ORDER BY c.ordem;

-- Verificar usuários criados
SELECT 
    id, 
    nome, 
    email, 
    tipo_usuario,
    DATE_FORMAT(data_criacao, '%d/%m/%Y %H:%i') as criado_em
FROM usuarios 
ORDER BY id;

SELECT 'BANCO CONFIGURADO COM SUCESSO!' as status;