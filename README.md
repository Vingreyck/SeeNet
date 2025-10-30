# SeeNet

<div align="center">

**Sistema de Suporte Técnico Inteligente para ISPs**

*Empowering Seamless Connectivity Through Intelligent Diagnostics*

[![Dart](https://img.shields.io/badge/dart-86.9%25-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/flutter-3.24%2B-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/node.js-18%2B-339933?style=flat-square&logo=node.js&logoColor=white)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-15%2B-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/license-Proprietary-red?style=flat-square)](LICENSE)

[Características](#-características) • [Instalação](#-instalação) • [Documentação](#-documentação) • [Tecnologias](#-tecnologias) • [Contribuir](#-contribuindo)

</div>

---

## 📋 Visão Geral

**SeeNet** é uma plataforma completa de gerenciamento de suporte técnico projetada especificamente para técnicos de ISP (Provedores de Serviços de Internet). O sistema combina checklists de diagnóstico estruturados com inteligência artificial para automatizar análises técnicas e organizar documentação de campo através de transcrição de voz.

### 🎯 Problema Resolvido

Técnicos de campo enfrentam desafios diários:
- Diagnósticos inconsistentes e não padronizados
- Documentação manual demorada e propensa a erros
- Falta de histórico organizado de atendimentos
- Dificuldade em gerar relatórios técnicos profissionais

**SeeNet resolve isso** oferecendo diagnósticos guiados por IA, transcrição automática de áudio e multi-tenancy completo para isolamento de dados entre empresas.

---

## ✨ Características

### 🔐 Multi-Tenancy Robusto
- Isolamento completo de dados entre empresas
- Código único por organização
- Limite configurável de usuários por tenant
- Auditoria independente por empresa

### 🤖 Diagnósticos com IA
- Integração com **Google Gemini 2.0 Flash**
- Geração automática de relatórios técnicos
- Análise baseada em checklists personalizáveis
- Resumos inteligentes de problemas identificados

### 🎤 Documentação por Voz
- Conversão de áudio em texto (speech-to-text)
- Organização automática de pontos de ação
- Categorização inteligente de problemas
- Histórico completo de atendimentos

### 👥 Controle de Acesso
- **Admin**: Gerenciamento completo de categorias e checklists
- **Técnico**: Criação de avaliações e diagnósticos
- Autenticação JWT com expiração configurável
- Rate limiting para proteção contra ataques

### 📊 Sistema de Auditoria
- Registro de todas as operações críticas
- Snapshots de dados antes/depois de modificações
- Rastreamento de IP e user agent
- Níveis de severidade (info, warning, error)

---

## 🚀 Instalação

### Pré-requisitos

```bash
# Verificar versões necessárias
node --version    # >= 18.0.0
npm --version     # >= 9.0.0
flutter --version # >= 3.24.0
psql --version    # >= 15.0
```

### Backend Setup

```bash
# 1. Clone o repositório
git clone https://github.com/Vingreyck/SeeNet.git
cd SeeNet/backend

# 2. Instale as dependências
npm install

# 3. Configure as variáveis de ambiente
cp .env.example .env
```

Edite o arquivo `.env`:

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/seenet

# JWT
JWT_SECRET=seu-secret-key-super-seguro-aqui

# Google Gemini
GEMINI_API_KEY=sua-chave-api-gemini

# Server
PORT=3000
NODE_ENV=development
```

```bash
# 4. Execute as migrations
npm run migrate

# 5. (Opcional) Popule dados de demonstração
npm run seed

# 6. Inicie o servidor de desenvolvimento
npm run dev
```

O backend estará disponível em `http://localhost:3000` 🚀

### Frontend Setup

```bash
# 1. Navegue para o diretório Flutter
cd ../seenet_flutter

# 2. Instale as dependências
flutter pub get

# 3. Configure o ambiente
cp .env.example .env
```

Edite o arquivo `.env`:

```env
# API Configuration
API_BASE_URL=http://localhost:3000/api
API_TIMEOUT=30000

# Environment
ENVIRONMENT=development
```

```bash
# 4. Execute a aplicação
flutter run
```

---

## 🛠️ Tecnologias

### Backend

| Tecnologia | Versão | Propósito |
|-----------|--------|-----------|
| **Node.js** | 18+ | Runtime JavaScript |
| **Express.js** | 4.x | Framework web |
| **PostgreSQL** | 15+ | Banco de dados relacional |
| **Knex.js** | 3.x | Query builder SQL |
| **JWT** | - | Autenticação stateless |
| **Bcrypt** | - | Hash de senhas |
| **Google Gemini** | 2.0 Flash | IA para diagnósticos |

### Frontend

| Tecnologia | Versão | Propósito |
|-----------|--------|-----------|
| **Flutter** | 3.24+ | Framework UI multiplataforma |
| **GetX** | 4.x | Gerenciamento de estado |
| **HTTP** | - | Cliente REST |
| **Shared Preferences** | - | Armazenamento local |
| **Speech to Text** | - | Reconhecimento de voz |
| **Material Design 3** | - | Sistema de design |

### DevOps & Infraestrutura

- **Docker**: Containerização
- **Railway**: Hosting de produção
- **GitHub Actions**: CI/CD
- **Artillery**: Testes de carga

---

## 📚 Documentação

Documentação completa disponível na pasta `/docs`:

- **[Arquitetura do Sistema](docs/ARCHITECTURE.md)** - Design patterns, fluxos de dados, decisões arquiteturais
- **[API Documentation](docs/API.md)** - Referência completa de endpoints, exemplos de uso
- **[Database Schema](docs/DATABASE.md)** - Estrutura de tabelas, relacionamentos, queries úteis
- **[Guia de Testes](docs/TESTING.md)** - Estratégias de teste, cobertura, CI/CD

### Endpoints Principais

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `POST` | `/api/auth/register` | Criar nova conta |
| `POST` | `/api/auth/login` | Autenticar usuário |
| `POST` | `/api/diagnostics/gerar` | Gerar diagnóstico com IA |
| `POST` | `/api/transcriptions` | Criar transcrição de voz |
| `GET` | `/api/avaliacoes` | Listar avaliações |

Veja a [documentação completa da API](docs/API.md) para detalhes.

---

## 🧪 Testes

### Backend

```bash
# Executar todos os testes
npm test

# Testes com cobertura
npm run test:coverage

# Testes unitários apenas
npm run test:unit

# Testes de integração
npm run test:integration

# Modo watch
npm run test:watch
```

### Frontend

```bash
# Testes unitários e de widget
flutter test

# Testes de integração
flutter test integration_test/

# Gerar relatório de cobertura
flutter test --coverage
```

### Testes de Carga

```bash
# Instalar Artillery
npm install -g artillery

# Executar testes de performance
artillery run artillery.yml
```

**Metas de Cobertura:**
- Testes Unitários: **80%+**
- Testes de Integração: Fluxos principais
- Testes E2E: Caminhos críticos

---

## 🔐 Segurança

SeeNet implementa múltiplas camadas de segurança:

- ✅ **Hash de senhas** com Bcrypt (10 rounds)
- ✅ **Tokens JWT** com expiração de 24 horas
- ✅ **Proteção contra SQL Injection** via queries parametrizadas
- ✅ **Proteção XSS** através de sanitização de inputs
- ✅ **CORS configurado** para ambientes de produção
- ✅ **Rate Limiting** em endpoints de autenticação
- ✅ **Auditoria completa** de todas as operações críticas

### Multi-Tenancy Security

Todas as queries incluem automaticamente `tenant_id` via middleware, garantindo isolamento completo de dados entre empresas.

---

## 📱 Deploy

### Backend (Railway)

```bash
# 1. Conecte seu repositório ao Railway
# 2. Configure as variáveis de ambiente no dashboard
# 3. Deploy automático

railway up
```

### Frontend

#### Android
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ipa --release
```

---

## ⚡ Performance

### Otimizações Implementadas

**Backend:**
- Connection pooling (máximo 20 conexões)
- Índices estratégicos no banco de dados
- Compressão de resposta (gzip)
- Cache de dados estáticos

**Frontend:**
- Lazy loading de componentes pesados
- Cache inteligente de imagens
- Debouncing em campos de busca
- Virtual scrolling para listas longas

**Benchmarks:**
- Lookup de usuário: **< 50ms**
- Listagem com joins: **< 200ms**
- Geração de diagnóstico: **< 5s** (dependente da API Gemini)

---

## 🐛 Limitações Conhecidas

- Transcrição de voz requer permissão de microfone do dispositivo
- Diagnósticos com IA requerem conexão ativa com a internet
- Máximo de 20 conexões simultâneas no banco de dados
- Upload de arquivos ainda não implementado
- Modo offline não disponível

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. **Fork** o projeto
2. Crie uma **branch** para sua feature (`git checkout -b feature/MinhaFeature`)
3. **Commit** suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. **Push** para a branch (`git push origin feature/MinhaFeature`)
5. Abra um **Pull Request**

### Diretrizes

- Mantenha cobertura de testes acima de 80%
- Siga os padrões de código existentes
- Documente novas funcionalidades
- Adicione testes para novas features
- Atualize o CHANGELOG.md

---

## 📊 Roadmap

- [ ] Modo offline com sincronização
- [ ] Upload e anexo de arquivos
- [ ] Integração com WhatsApp Business
- [ ] Dashboard analítico para gestores
- [ ] Exportação de relatórios em PDF
- [ ] Suporte a múltiplos idiomas
- [ ] App mobile nativo para iOS

---

## 📄 Licença

Este projeto é **proprietário**. Todos os direitos reservados.

Para informações sobre licenciamento comercial, entre em contato: support@seenet.com

---

## 👥 Autores

- **Equipe SeeNet** - *Desenvolvimento Inicial* - [GitHub](https://github.com/Vingreyck)

---

## 🙏 Agradecimentos

- [Flutter Team](https://flutter.dev/) pelo framework excepcional
- [Google Gemini](https://ai.google.dev/) pela API de IA
- [Railway](https://railway.app/) pela infraestrutura de hosting
- Comunidade open-source pelos pacotes utilizados

---

<div align="center">

**Desenvolvido usando Flutter e Node.js**

⭐ Star este projeto se ele foi útil para você!

</div>
