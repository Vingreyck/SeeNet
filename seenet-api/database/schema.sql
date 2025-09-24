-- ============================================
-- SEENET DATABASE SCHEMA - POSTGRESQL
-- ============================================

-- Limpar tabelas se existirem (ordem importante por FK)
DROP TABLE IF EXISTS logs_sistema CASCADE;
DROP TABLE IF EXISTS transcricoes_tecnicas CASCADE;
DROP TABLE IF EXISTS diagnosticos CASCADE;
DROP TABLE IF EXISTS respostas_checkmark CASCADE;
DROP TABLE IF EXISTS checkmarks CASCADE;
DROP TABLE IF EXISTS categorias_checkmark CASCADE;
DROP TABLE IF EXISTS avaliacoes CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;

-- ============================================
-- TABELA: usuarios
-- ============================================
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    tipo_usuario VARCHAR(20) NOT NULL CHECK (tipo_usuario IN ('tecnico', 'administrador')),
    ativo BOOLEAN DEFAULT TRUE,
    tentativas_login INTEGER DEFAULT 0,
    ultimo_login TIMESTAMP,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_tipo ON usuarios(tipo_usuario);
CREATE INDEX idx_usuarios_ativo ON usuarios(ativo);

-- ============================================
-- TABELA: categorias_checkmark
-- ============================================
CREATE TABLE categorias_checkmark (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    ativo BOOLEAN DEFAULT TRUE,
    ordem INTEGER DEFAULT 0,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX idx_categorias_ativo_ordem ON categorias_checkmark(ativo, ordem);

-- ============================================
-- TABELA: checkmarks
-- ============================================
CREATE TABLE checkmarks (
    id SERIAL PRIMARY KEY,
    categoria_id INTEGER NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    descricao TEXT,
    prompt_chatgpt TEXT NOT NULL,
    ativo BOOLEAN DEFAULT TRUE,
    ordem INTEGER DEFAULT 0,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias_checkmark(id) ON DELETE CASCADE
);

-- Índices
CREATE INDEX idx_checkmarks_categoria ON checkmarks(categoria_id);
CREATE INDEX idx_checkmarks_ativo_ordem ON checkmarks(ativo, ordem);

-- ============================================
-- TABELA: avaliacoes
-- ============================================
CREATE TABLE avaliacoes (
    id SERIAL PRIMARY KEY,
    tecnico_id INTEGER NOT NULL,
    titulo VARCHAR(200),
    descricao TEXT,
    status VARCHAR(20) DEFAULT 'em_andamento' CHECK (status IN ('em_andamento', 'concluida', 'cancelada')),
    data_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_conclusao TIMESTAMP,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tecnico_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Índices
CREATE INDEX idx_avaliacoes_tecnico ON avaliacoes(tecnico_id);
CREATE INDEX idx_avaliacoes_status ON avaliacoes(status);
CREATE INDEX idx_avaliacoes_data ON avaliacoes(data_criacao);

-- ============================================
-- TABELA: respostas_checkmark
-- ============================================
CREATE TABLE respostas_checkmark (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL,
    checkmark_id INTEGER NOT NULL,
    marcado BOOLEAN DEFAULT FALSE,
    observacoes TEXT,
    data_resposta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id) ON DELETE CASCADE,
    FOREIGN KEY (checkmark_id) REFERENCES checkmarks(id) ON DELETE CASCADE,
    UNIQUE(avaliacao_id, checkmark_id)
);

-- Índices
CREATE INDEX idx_respostas_avaliacao ON respostas_checkmark(avaliacao_id);
CREATE INDEX idx_respostas_checkmark ON respostas_checkmark(checkmark_id);

-- ============================================
-- TABELA: diagnosticos
-- ============================================
CREATE TABLE diagnosticos (
    id SERIAL PRIMARY KEY,
    avaliacao_id INTEGER NOT NULL,
    categoria_id INTEGER NOT NULL,
    prompt_enviado TEXT NOT NULL,
    resposta_chatgpt TEXT NOT NULL,
    resumo_diagnostico TEXT,
    status_api VARCHAR(20) DEFAULT 'pendente' CHECK (status_api IN ('pendente', 'sucesso', 'erro')),
    erro_api TEXT,
    tokens_utilizados INTEGER,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id) ON DELETE CASCADE,
    FOREIGN KEY (categoria_id) REFERENCES categorias_checkmark(id) ON DELETE CASCADE
);

-- Índices
CREATE INDEX idx_diagnosticos_avaliacao ON diagnosticos(avaliacao_id);
CREATE INDEX idx_diagnosticos_categoria ON diagnosticos(categoria_id);
CREATE INDEX idx_diagnosticos_status ON diagnosticos(status_api);

-- ============================================
-- TABELA: transcricoes_tecnicas
-- ============================================
CREATE TABLE transcricoes_tecnicas (
    id SERIAL PRIMARY KEY,
    tecnico_id INTEGER NOT NULL,
    titulo VARCHAR(200) NOT NULL,
    descricao TEXT,
    transcricao_original TEXT NOT NULL,
    pontos_da_acao TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'concluida' CHECK (status IN ('gravando', 'processando', 'concluida', 'erro')),
    duracao_segundos INTEGER,
    categoria_problema VARCHAR(100),
    cliente_info TEXT,
    data_inicio TIMESTAMP,
    data_conclusao TIMESTAMP,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tecnico_id) REFERENCES usuarios(id) ON DELETE CASCADE
);

-- Índices
CREATE INDEX idx_transcricoes_tecnico ON transcricoes_tecnicas(tecnico_id);
CREATE INDEX idx_transcricoes_data ON transcricoes_tecnicas(data_criacao);
CREATE INDEX idx_transcricoes_status ON transcricoes_tecnicas(status);

-- ============================================
-- TABELA: logs_sistema
-- ============================================
CREATE TABLE logs_sistema (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER,
    acao VARCHAR(50) NOT NULL,
    nivel VARCHAR(20) NOT NULL,
    tabela_afetada VARCHAR(50),
    registro_id INTEGER,
    dados_anteriores JSONB,
    dados_novos JSONB,
    ip_address INET,
    user_agent TEXT,
    detalhes TEXT,
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- Índices para logs
CREATE INDEX idx_logs_usuario ON logs_sistema(usuario_id);
CREATE INDEX idx_logs_acao ON logs_sistema(acao);
CREATE INDEX idx_logs_data ON logs_sistema(data_acao);
CREATE INDEX idx_logs_nivel ON logs_sistema(nivel);

-- ============================================
-- TRIGGER PARA AUTO-UPDATE timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Aplicar trigger nas tabelas necessárias
CREATE TRIGGER update_usuarios_updated_at 
    BEFORE UPDATE ON usuarios 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_avaliacoes_updated_at 
    BEFORE UPDATE ON avaliacoes 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- INSERIR DADOS INICIAIS
-- ============================================

-- Usuários iniciais (senhas com hash seguro)
INSERT INTO usuarios (nome, email, senha, tipo_usuario) VALUES
('Administrador', 'admin@seenet.com', '$2a$10$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPjiCf7RW', 'administrador'),
('Técnico Teste', 'tecnico@seenet.com', '$2a$10$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPjiCf7RW', 'tecnico');

-- Categorias de checkmarks
INSERT INTO categorias_checkmark (nome, descricao, ordem) VALUES
('Lentidão', 'Problemas de velocidade, buffering e lentidão geral', 1),
('IPTV', 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', 2),
('Aplicativos', 'Apps não carregam, erro de carregamento da logo', 3),
('Acesso Remoto', 'Ativação de acessos remotos dos roteadores', 4);

-- Checkmarks para categoria Lentidão (id=1)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES
(1, 'Velocidade abaixo do contratado', 'Cliente relata velocidade de internet abaixo do contratado', 'Analise problema de velocidade abaixo do contratado. Forneça diagnóstico e soluções.', 1),
(1, 'Latência alta (ping > 100ms)', 'Ping alto causando travamentos', 'Cliente com ping alto acima de 100ms. Analise causas e soluções.', 2),
(1, 'Perda de pacotes', 'Perda de pacotes na conexão', 'Problema de perda de pacotes. Identifique causas e soluções.', 3),
(1, 'Wi-Fi com sinal fraco', 'Sinal WiFi fraco ou instável', 'Sinal WiFi fraco. Diagnóstico e melhorias de cobertura.', 4),
(1, 'Problemas no cabo', 'Problemas físicos no cabeamento', 'Problemas de cabeamento. Orientações para resolução.', 5);

-- Checkmarks para categoria IPTV (id=2)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES
(2, 'Canais travando/congelando', 'Canais de TV travando', 'Travamento nos canais IPTV. Soluções técnicas.', 1),
(2, 'Buffering constante', 'Buffering constante nos canais', 'IPTV com buffering constante. Diagnóstico e melhorias.', 2),
(2, 'Canal fora do ar', 'Canais específicos fora do ar', 'Canais IPTV fora do ar. Causas e soluções.', 3),
(2, 'Qualidade baixa', 'Qualidade de vídeo baixa', 'Qualidade ruim no IPTV. Diagnóstico e melhorias.', 4),
(2, 'IPTV não abre', 'Aplicativo IPTV não abre', 'IPTV não inicializa. Diagnóstico e soluções.', 5);

-- Checkmarks para categoria Aplicativos (id=3)
INSERT INTO checkmarks (categoria_id, titulo, descricao, prompt_chatgpt, ordem) VALUES
(3, 'Aplicativo não abre', 'Apps não conseguem abrir', 'Aplicativos não abrem. Diagnóstico e soluções.', 1),
(3, 'Erro de conexão', 'Apps com erro de conexão', 'Aplicativos com erro de conexão. Analise e solucione.', 2),
(3, 'Buffering constante', 'Apps com buffering constante', 'Aplicativos com buffering. Diagnóstico e soluções.', 3),
(3, 'Qualidade baixa', 'Qualidade baixa nos apps', 'Qualidade baixa nos aplicativos. Melhorias.', 4),
(3, 'Error code: xxxxx', 'Códigos de erro específicos', 'Aplicativo com códigos de erro. Soluções baseadas no código.', 5);

-- ============================================
-- COMENTÁRIOS E METADADOS
-- ============================================
COMMENT ON DATABASE seenet IS 'Base de dados do sistema SeeNet - Assistente técnico para redes';
COMMENT ON TABLE usuarios IS 'Usuários do sistema (técnicos e administradores)';
COMMENT ON TABLE categorias_checkmark IS 'Categorias de problemas técnicos';
COMMENT ON TABLE checkmarks IS 'Lista de verificações técnicas por categoria';
COMMENT ON TABLE avaliacoes IS 'Avaliações técnicas realizadas pelos técnicos';
COMMENT ON TABLE respostas_checkmark IS 'Respostas dos técnicos aos checkmarks';
COMMENT ON TABLE diagnosticos IS 'Diagnósticos gerados pela IA baseados nas respostas';
COMMENT ON TABLE transcricoes_tecnicas IS 'Documentação de ações técnicas via transcrição de voz';
COMMENT ON TABLE logs_sistema IS 'Logs de auditoria e ações no sistema';

-- ============================================
-- VERSIONING
-- ============================================
INSERT INTO logs_sistema (acao, nivel, detalhes) VALUES 
('SCHEMA_CREATED', 'info', 'Schema PostgreSQL criado - versão 1.0');

COMMIT;