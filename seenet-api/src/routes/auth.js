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
  max: 5, // máximo 5 tentativas de login por IP
  message: { error: 'Muitas tentativas de login. Tente novamente em 15 minutos.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// ========== REGISTRO DE USUÁRIO ==========
router.post('/register', [
  body('nome').trim().isLength({ min: 2, max: 100 }).withMessage('Nome deve ter entre 2 e 100 caracteres'),
  body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
  body('senha').isLength({ min: 6, max: 128 }).withMessage('Senha deve ter entre 6 e 128 caracteres'),
  body('codigoEmpresa').trim().isLength({ min: 3, max: 20 }).withMessage('Código da empresa inválido'),
], async (req, res) => {
  try {
    // Verificar erros de validação
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { nome, email, senha, codigoEmpresa } = req.body;

    // Verificar se o tenant existe e está ativo
    const tenant = await db('tenants')
      .where('codigo', codigoEmpresa.toUpperCase())
      .where('ativo', 1) // ← MUDAR: true para 1
      .first();

    if (!tenant) {
      return res.status(400).json({ 
        error: 'Código da empresa inválido ou empresa inativa' 
      });
    }

    // Verificar se email já existe no tenant
    const existingUser = await db('usuarios')
      .where('email', email.toLowerCase())
      .where('tenant_id', tenant.id)
      .first();

    if (existingUser) {
      return res.status(400).json({ 
        error: 'Este email já está cadastrado nesta empresa' 
      });
    }

    // Verificar limite de usuários do plano
    const userCount = await db('usuarios')
      .where('tenant_id', tenant.id)
      .where('ativo', 1) // ← MUDAR: true para 1
      .count('id as total')
      .first();

    const limits = {
      'basico': 5,
      'profissional': 25,
      'empresarial': 100,
      'enterprise': -1 // ilimitado
    };

    const maxUsers = limits[tenant.plano] || 5;
    if (maxUsers !== -1 && userCount.total >= maxUsers) {
      return res.status(400).json({ 
        error: `Limite de usuários atingido para o plano ${tenant.plano}. Máximo: ${maxUsers}` 
      });
    }

    // Hash da senha
    const senhaHash = await bcrypt.hash(senha, 12);

    // Criar usuário
    const [userId] = await db('usuarios').insert({
      nome,
      email: email.toLowerCase(),
      senha: senhaHash,
      tenant_id: tenant.id,
      tipo_usuario: 'tecnico', // Novos usuários sempre como técnico
      ativo: 1,
      data_criacao: new Date().toISOString(),
    });

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
    logger.error('Erro no registro:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LOGIN ==========
router.post('/login', loginLimiter, [
  body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
  body('senha').notEmpty().withMessage('Senha é obrigatória'),
  body('codigoEmpresa').trim().isLength({ min: 3, max: 20 }).withMessage('Código da empresa inválido'),
], async (req, res) => {
  try {
    // Verificar erros de validação
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { email, senha, codigoEmpresa } = req.body;

    // Buscar usuário com tenant
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.email', email.toLowerCase())
      .where('tenants.codigo', codigoEmpresa.toUpperCase())
      .where('usuarios.ativo', 1)
      .where('tenants.ativo', 1)
      .select(
        'usuarios.*',
        'tenants.id as tenant_id',
        'tenants.codigo as tenant_code',
        'tenants.nome as tenant_name',
        'tenants.plano as tenant_plan'
      )
      .first();

    if (!user) {
      await auditService.log({
        action: 'LOGIN_FAILED',
        details: `Tentativa de login falhada: ${email} - Tenant: ${codigoEmpresa}`,
        ip_address: req.ip
      });

      return res.status(401).json({ 
        error: 'Credenciais inválidas ou empresa não encontrada' 
      });
    }

    // Verificar senha
    const senhaValida = await bcrypt.compare(senha, user.senha);
    if (!senhaValida) {
      await auditService.log({
        action: 'LOGIN_FAILED',
        usuario_id: user.id,
        tenant_id: user.tenant_id,
        details: `Senha incorreta: ${email}`,
        ip_address: req.ip
      });

      return res.status(401).json({ 
        error: 'Credenciais inválidas' 
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

    // Log de auditoria
    await auditService.log({
      action: 'LOGIN_SUCCESS',
      usuario_id: user.id,
      tenant_id: user.tenant_id,
      details: `Login bem-sucedido: ${email}`,
      ip_address: req.ip
    });

    logger.info(`✅ Login bem-sucedido: ${email} - Tenant: ${user.tenant_name}`);

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
    logger.error('Erro no login:', error);
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
      .where('usuarios.ativo', 1)
      .where('tenants.ativo', 1)
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