const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

const { db } = require('../config/database');
const logger = require('../config/logger');
const auditService = require('../services/auditService');

const router = express.Router();

// Rate limiting para login (mais restritivo)
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos MUDAR PARA 15 AQUI 
  max: 999, // máximo 5 tentativas de login por IP
  message: { error: 'Muitas tentativas de login. Tente novamente em 15 minutos.' },
  standardHeaders: true,
  legacyHeaders: false,
});


// ========== REGISTRO DE USUÁRIO ========== (VERSÃO CORRIGIDA)
router.post('/register', [
  body('nome').trim().isLength({ min: 2, max: 100 }).withMessage('Nome deve ter entre 2 e 100 caracteres'),
  body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
  body('senha').isLength({ min: 6, max: 128 }).withMessage('Senha deve ter entre 6 e 128 caracteres'),
  body().custom((value, { req }) => {
    const codigo = req.body.codigoEmpresa || req.body.tenantCode;
    if (!codigo || codigo.trim().length < 3 || codigo.trim().length > 20) {
      throw new Error('Código da empresa inválido');
    }
    return true;
  })
], async (req, res) => {
  const requestContext = {
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    email: req.body.email,
    tenantCode: req.body.codigoEmpresa || req.body.tenantCode,
    timestamp: new Date().toISOString()
  };

  try {
    logger.info('Iniciando registro de usuário', {
      ...requestContext,
      nome: req.body.nome
    });

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Erros de validação:', errors.array());
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { nome, email, senha } = req.body;
    const codigoEmpresa = req.body.codigoEmpresa || req.body.tenantCode;

    console.log('✅ Validação OK');
    console.log('👤 Nome:', nome);
    console.log('📧 Email:', email);
    console.log('🏢 Código Empresa:', codigoEmpresa);

    // Verificar se o tenant existe e está ativo
    const tenant = await db('tenants')
      .where('codigo', codigoEmpresa.toUpperCase())
      .where('ativo', true)
      .first();

    if (!tenant) {
      console.log('❌ Tenant não encontrado:', codigoEmpresa);
      return res.status(400).json({ 
        error: 'Código da empresa inválido ou empresa inativa' 
      });
    }

    console.log('✅ Tenant encontrado:', tenant.nome, '- ID:', tenant.id);

    // Verificar se email já existe no tenant
    const existingUser = await db('usuarios')
      .where('email', email.toLowerCase())
      .where('tenant_id', tenant.id)
      .first();

    if (existingUser) {
      console.log('❌ Email já existe:', email);
      return res.status(400).json({ 
        error: 'Este email já está cadastrado nesta empresa' 
      });
    }

    console.log('✅ Email disponível');

    // Verificar limite de usuários do plano
    const userCount = await db('usuarios')
      .where('tenant_id', tenant.id)
      .where('ativo', true)
      .count('id as total')
      .first();

    const limits = {
      'basico': 5,
      'profissional': 25,
      'empresarial': 100,
      'enterprise': -1
    };

    const maxUsers = limits[tenant.plano] || 5;
    if (maxUsers !== -1 && userCount.total >= maxUsers) {
      console.log('❌ Limite de usuários atingido:', userCount.total, '/', maxUsers);
      return res.status(400).json({ 
        error: `Limite de usuários atingido para o plano ${tenant.plano}. Máximo: ${maxUsers}` 
      });
    }

    console.log('✅ Limite de usuários OK:', userCount.total, '/', maxUsers);

    // Hash da senha
    const senhaHash = await bcrypt.hash(senha, 12);
    console.log('✅ Senha hasheada');

    // ✅ CORREÇÃO: Remover data_criacao (usar default do banco)
    const novoUsuario = {
      nome,
      email: email.toLowerCase(),
      senha: senhaHash,
      tenant_id: tenant.id,
      tipo_usuario: 'tecnico',
      ativo: true,
      // ❌ REMOVIDO: data_criacao (deixar o banco usar o default)
    };

    console.log('📝 Objeto para inserir:', {
      ...novoUsuario,
      senha: '[HASH]' // Não mostrar a senha no log
    });

    // Criar usuário
    const [result] = await db('usuarios')
      .insert(novoUsuario)
      .returning('id');

    const userId = result.id;

    console.log('✅ Usuário criado com ID:', userId);

    // Log de auditoria
    await auditService.log({
      action: 'USER_REGISTERED',
      usuario_id: userId,
      tenant_id: tenant.id,
      details: `Usuário registrado: ${email}`,
      ip_address: req.ip
    });

    logger.info(`✅ Usuário registrado: ${email} - Tenant: ${tenant.nome}`);

    res.status(201).json({
      message: 'Usuário criado com sucesso',
      tenantName: tenant.nome
    });

  } catch (error) {
    console.error('❌ ERRO CRÍTICO NO REGISTRO:', error);
    console.error('Stack trace:', error.stack);
    console.error('Detalhes do erro:', {
      message: error.message,
      code: error.code,
      detail: error.detail
    });
    
    logger.error('Erro no registro:', error);
    res.status(500).json({ 
      error: 'Erro interno do servidor',  // ✅ vírgula
      details: error.message              // ✅ que adicionamos agora para debug
    });
  }
});


// ========== LOGIN ==========
router.post('/login', loginLimiter, [
  body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
  body('senha').notEmpty().withMessage('Senha é obrigatória'),
  body().custom((value, { req }) => {
    const codigo = req.body.codigoEmpresa || req.body.tenantCode;
    if (!codigo || codigo.trim().length < 3 || codigo.trim().length > 20) {
      throw new Error('Código da empresa é obrigatório');
    }
    return true;
  })
], async (req, res) => {
  const requestContext = {
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    email: req.body.email?.toLowerCase(),
    tenantCode: (req.body.codigoEmpresa || req.body.tenantCode)?.toUpperCase(),
    timestamp: new Date().toISOString()
  };

  try {    
    // Log inicial da tentativa de login
    logger.info('Iniciando tentativa de login', {
      ...requestContext,
      headers: {
        ...req.headers,
        authorization: undefined // Não logar authorization header
      }
    });

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Erros de validação:', errors.array()); // ✅ ADICIONAR
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { email, senha } = req.body;
    const codigoEmpresa = req.body.codigoEmpresa || req.body.tenantCode;

    console.log('✅ Validação OK - Buscando usuário:', email, codigoEmpresa); // ✅ ADICIONAR


    // Buscar usuário com tenant
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.email', email.toLowerCase())
      .where('tenants.codigo', codigoEmpresa.toUpperCase())
      .whereRaw('usuarios.ativo = ?', [true])
      .whereRaw('tenants.ativo = ?', [true])
      .select(
        'usuarios.*',
        'tenants.id as tenant_id',
        'tenants.codigo as tenant_code',
        'tenants.nome as tenant_name',
        'tenants.plano as tenant_plan'
      )
      .first();

    if (!user) {
      // Log de falha na autenticação
      logger.warn('Tentativa de login falhou - usuário/tenant não encontrado', {
        ...requestContext,
        reason: 'USER_NOT_FOUND'
      });

      await auditService.log({
        action: 'LOGIN_FAILED',
        details: `Tentativa de login falhou: ${email} - Tenant: ${codigoEmpresa}`,
        ip_address: req.ip,
        reason: 'USER_NOT_FOUND'
      });

      return res.status(401).json({ 
        error: 'Usuário não encontrado ou empresa inválida',
        type: 'USER_NOT_FOUND'
      });
    }

    // Verificar senha
    const senhaValida = await bcrypt.compare(senha, user.senha);
    if (!senhaValida) {
      // Log de falha na autenticação
      logger.warn('Tentativa de login falhou - senha incorreta', {
        ...requestContext,
        userId: user.id,
        tenantId: user.tenant_id,
        reason: 'INVALID_PASSWORD',
        loginAttempts: (user.tentativas_login || 0) + 1
      });

      await auditService.log({
        action: 'LOGIN_FAILED',
        usuario_id: user.id,
        tenant_id: user.tenant_id,
        details: `Senha incorreta: ${email}`,
        ip_address: req.ip,
        reason: 'INVALID_PASSWORD'
      });

      // Incrementar tentativas de login
      await db('usuarios')
        .where('id', user.id)
        .increment('tentativas_login', 1);

      return res.status(401).json({ 
        error: 'Senha incorreta',
        type: 'INVALID_PASSWORD'
      });
    }

    // Atualizar último login
    await db('usuarios')
      .where('id', user.id)
      .update({
        ultimo_login: new Date().toISOString(),
        tentativas_login: 0 // Reset tentativas
      });

    // Gerar JWT
    const token = jwt.sign(
      { 
        userId: user.id,
        tenantId: user.tenant_id,
        tenantCode: user.tenant_code,
        tipo: user.tipo_usuario 
      },
      process.env.JWT_SECRET,
      { 
        expiresIn: process.env.JWT_EXPIRES_IN || '8h',
        issuer: 'seenet-api',
        audience: user.tenant_code
      }
    );

if (user.tipo_usuario === 'tecnico') {
  try {
    const jaExiste = await db('mapeamento_tecnicos_ixc')
      .where({ usuario_id: user.id, tenant_id: user.tenant_id })
      .first();

    if (!jaExiste) {
      const integracao = await db('integracao_ixc')
        .where({ tenant_id: user.tenant_id, ativo: true })
        .first();

      if (integracao) {
        const axios = require('axios');
        const removerAcentos = (str) => str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
        // Busca TODOS os funcionários e filtra localmente
        const params = new URLSearchParams({
          qtype: 'id',
          query: '',
          oper: '!=',
          page: '1',
          rp: '200'  // busca em massa
        });

        const resp = await axios.post(
          `${integracao.url_api}/funcionario`,
          params.toString(),
          {
            headers: {
              'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
              'Content-Type': 'application/x-www-form-urlencoded',
              'ixcsoft': 'listar'
            },
            timeout: 10000
          }
        );

        const funcionarios = resp.data.registros || [];
        console.log(`🔍 ${funcionarios.length} funcionários carregados do IXC`);

        const nomeNormalizado = removerAcentos(user.nome).toLowerCase().trim();

        const match = funcionarios.find(f =>
          removerAcentos(f.nome).toLowerCase().trim() === nomeNormalizado
        );


        if (match) {
          await db('mapeamento_tecnicos_ixc').insert({
            usuario_id: user.id,
            tecnico_ixc_id: match.id,
            tenant_id: user.tenant_id
          });
          console.log(`✅ Auto-mapeamento: ${user.nome} → IXC ID ${match.id}`);
        } else {
          console.log(`⚠️ Auto-mapeamento falhou: nenhum match para "${user.nome}"`);
        }
      }
    }
  } catch (e) {
    console.error('⚠️ Erro no auto-mapeamento:', e.message);
  }
}

    // Log de auditoria
    await auditService.log({
      action: 'LOGIN_SUCCESS',
      usuario_id: user.id,
      tenant_id: user.tenant_id,
      details: `Login bem-sucedido: ${email}`,
      ip_address: req.ip
    });

    // Log de sucesso
    logger.info('Login bem-sucedido', {
      ...requestContext,
      userId: user.id,
      userName: user.nome,
      userType: user.tipo_usuario,
      tenantId: user.tenant_id,
      tenantName: user.tenant_name,
      tenantPlan: user.tenant_plan
    });

    res.json({
      token,
      user: {
        id: user.id,
        nome: user.nome,
        email: user.email,
        tipo_usuario: user.tipo_usuario,
        tenant: {
          id: user.tenant_id,
          codigo: user.tenant_code,
          nome: user.tenant_name,
          plano: user.tenant_plan
        }
      }
    });

  } catch (error) {
    console.error('❌ ERRO CRÍTICO NO LOGIN:', error);
    console.error('Stack trace:', error.stack);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== VERIFICAR TOKEN ==========
router.get('/verify', async (req, res) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Token não fornecido' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Buscar usuário atual
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.id', decoded.userId)
      .where('usuarios.ativo', true)
      .where('tenants.ativo', true)
      .select(
        'usuarios.id',
        'usuarios.nome',
        'usuarios.email',
        'usuarios.tipo_usuario',
        'tenants.id as tenant_id',
        'tenants.codigo as tenant_code',
        'tenants.nome as tenant_name',
        'tenants.plano as tenant_plan'
      )
      .first();

    if (!user) {
      return res.status(401).json({ error: 'Usuário não encontrado' });
    }

    res.json({
      valid: true,
      user: {
        id: user.id,
        nome: user.nome,
        email: user.email,
        tipo_usuario: user.tipo_usuario,
        tenant: {
          id: user.tenant_id,
          codigo: user.tenant_code,
          nome: user.tenant_name,
          plano: user.tenant_plan
        }
      }
    });

  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expirado', valid: false });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token inválido', valid: false });
    }

    logger.error('Erro na verificação do token:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LOGOUT ==========
router.post('/logout', async (req, res) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Log de auditoria
      await auditService.log({
        action: 'LOGOUT',
        usuario_id: decoded.userId,
        tenant_id: decoded.tenantId,
        details: 'Logout realizado',
        ip_address: req.ip
      });
    }

    res.json({ message: 'Logout realizado com sucesso' });
  } catch (error) {
    // Mesmo com erro, permitir logout
    res.json({ message: 'Logout realizado' });
  }
});
// ========== ENDPOINTS DE DEBUG ==========

// ========== ENDPOINTS DE GERENCIAMENTO DE USUÁRIOS ==========

// Editar usuário
router.put('/usuarios/:id', [
  body('nome').optional().trim().isLength({ min: 2, max: 100 }),
  body('email').optional().isEmail().normalizeEmail(),
  body('senha').optional().isLength({ min: 6, max: 128 }),
  body('tipo_usuario').optional().isIn(['tecnico', 'administrador']),
  body('ativo').optional().isBoolean(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { id } = req.params;
    const { nome, email, senha, tipo_usuario, ativo } = req.body;

    // Verificar se usuário existe
    const user = await db('usuarios').where('id', id).first();
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    // Preparar dados para atualização
    const updateData = {
      data_atualizacao: new Date().toISOString()
    };

    if (nome) updateData.nome = nome;
    if (email) updateData.email = email.toLowerCase();
    if (tipo_usuario) updateData.tipo_usuario = tipo_usuario;
    if (typeof ativo === 'boolean') updateData.ativo = ativo;
    
    // Se senha fornecida, fazer hash
    if (senha) {
      updateData.senha = await bcrypt.hash(senha, 12);
    }

    await db('usuarios').where('id', id).update(updateData);

    await auditService.log({
      action: 'USER_UPDATED',
      usuario_id: id,
      details: `Usuário atualizado: ${Object.keys(updateData).join(', ')}`,
      ip_address: req.ip
    });

    res.json({ success: true, message: 'Usuário atualizado com sucesso' });
  } catch (error) {
    logger.error('Erro ao editar usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Resetar senha
router.put('/usuarios/:id/resetar-senha', [
  body('nova_senha').isLength({ min: 6, max: 128 }).withMessage('Nova senha deve ter entre 6 e 128 caracteres'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { id } = req.params;
    const { nova_senha } = req.body;

    const user = await db('usuarios').where('id', id).first();
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    const senhaHash = await bcrypt.hash(nova_senha, 12);
    
    await db('usuarios').where('id', id).update({
      senha: senhaHash,
      data_atualizacao: new Date().toISOString()
    });

    await auditService.log({
      action: 'PASSWORD_RESET',
      usuario_id: id,
      details: `Senha resetada para usuário: ${user.email}`,
      ip_address: req.ip
    });

    res.json({ success: true, message: 'Senha resetada com sucesso' });
  } catch (error) {
    logger.error('Erro ao resetar senha:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Atualizar status (ativar/desativar)
router.put('/usuarios/:id/status', [
  body('ativo').isBoolean().withMessage('Status deve ser true ou false'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { id } = req.params;
    const { ativo } = req.body;

    const user = await db('usuarios').where('id', id).first();
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    await db('usuarios').where('id', id).update({
      ativo,
      data_atualizacao: new Date().toISOString()
    });

    await auditService.log({
      action: 'USER_STATUS_CHANGED',
      usuario_id: id,
      details: `Status alterado para: ${ativo ? 'ativo' : 'inativo'}`,
      ip_address: req.ip
    });

    res.json({ success: true, message: `Usuário ${ativo ? 'ativado' : 'desativado'} com sucesso` });
  } catch (error) {
    logger.error('Erro ao atualizar status:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Remover usuário
router.delete('/usuarios/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const user = await db('usuarios').where('id', id).first();
    if (!user) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    await db('usuarios').where('id', id).del();

    await auditService.log({
      action: 'USER_DELETED',
      details: `Usuário removido: ${user.email} (ID: ${id})`,
      ip_address: req.ip
    });

    res.json({ success: true, message: 'Usuário removido com sucesso' });
  } catch (error) {
    logger.error('Erro ao remover usuário:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Debug - Listar usuários
router.get('/debug/usuarios', async (req, res) => {
  try {
    const usuarios = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .select(
        'usuarios.id',
        'usuarios.nome',
        'usuarios.email',
        'usuarios.tipo_usuario',
        'usuarios.ativo',
        'usuarios.data_criacao',
        'usuarios.ultimo_login',
        'tenants.nome as empresa',
        'tenants.codigo as codigo_empresa'
      )
      .orderBy('usuarios.data_criacao', 'desc');
    
    res.json({
      message: 'Usuários na API Node.js',
      total: usuarios.length,
      usuarios: usuarios
    });
  } catch (error) {
    logger.error('❌ Erro ao listar usuários:', error);
    res.status(500).json({ error: error.message });
  }
});

// Debug - Atualizar tipo de usuário
router.post('/debug/update-user-type', async (req, res) => {
  try {
    const { email, tipo } = req.body;
    
    if (!email || !tipo) {
      return res.status(400).json({ error: 'Email e tipo são obrigatórios' });
    }

    if (!['tecnico', 'administrador'].includes(tipo)) {
      return res.status(400).json({ error: 'Tipo deve ser "tecnico" ou "administrador"' });
    }

    // Atualizar usuário
    const updated = await db('usuarios')
      .where('email', email.toLowerCase())
      .update({ 
        tipo_usuario: tipo,
        data_atualizacao: new Date().toISOString()
      });

    if (updated === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }
    
    // Buscar usuário atualizado
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.email', email.toLowerCase())
      .select(
        'usuarios.id',
        'usuarios.nome',
        'usuarios.email',
        'usuarios.tipo_usuario',
        'tenants.nome as empresa'
      )
      .first();

    // Log de auditoria
    await auditService.log({
      action: 'USER_UPDATED',
      usuario_id: user.id,
      tenant_id: user.tenant_id,
      details: `Tipo de usuário alterado para: ${tipo}`,
      ip_address: req.ip
    });
    
    logger.info(`✅ Tipo atualizado: ${email} -> ${tipo}`);
    
    res.json({ 
      message: 'Tipo de usuário atualizado',
      user: {
        email: user.email,
        nome: user.nome,
        tipo_usuario: user.tipo_usuario,
        empresa: user.empresa
      }
    });
  } catch (error) {
    logger.error('❌ Erro ao atualizar tipo:', error);
    res.status(500).json({ error: error.message });
  }
});

// Debug - Limpar rate limit
router.post('/debug/clear-rate-limit', async (req, res) => {
  try {
    // O rate limit do express-rate-limit é automaticamente limpo ao reiniciar
    res.json({ 
      message: 'Para limpar rate limit, reinicie o servidor',
      tip: 'Ctrl+C e npm start novamente'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;