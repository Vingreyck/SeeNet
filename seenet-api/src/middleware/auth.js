const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const logger = require('../config/logger');

const authMiddleware = async (req, res, next) => {
  const requestContext = {
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    timestamp: new Date().toISOString()
  };

  try {
    // Log inicial da requisição de autenticação
    logger.debug('Iniciando verificação de acesso', {
      ...requestContext,
      hasToken: req.header('Authorization') ? true : false,
      hasTenantCode: req.header('X-Tenant-Code') ? true : false
    });
    
    const token = req.header('Authorization')?.replace('Bearer ', '');
    const tenantCode = req.header('X-Tenant-Code');

    if (!token || !tenantCode) {
      logger.warn('Autenticação falhou - credenciais ausentes', {
        ...requestContext,
        hasToken: !!token,
        hasTenantCode: !!tenantCode
      });
      return res.status(401).json({ 
        error: !token ? 'Token de acesso requerido' : 'Código da empresa requerido' 
      });
    }

    // Verificar token
    let decoded;
    decoded = jwt.verify(token, process.env.JWT_SECRET);
    logger.debug('Token JWT verificado', {
      userId: decoded.userId,
      tenantId: decoded.tenantId,
      exp: decoded.exp
    });
    
    // Buscar e validar usuário e tenant
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.id', decoded.userId)
      .where('tenants.codigo', tenantCode)
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
      logger.warn('Autenticação falhou - usuário/tenant inválido', {
        ...requestContext,
        userId: decoded.userId,
        tenantCode,
        reason: 'INVALID_USER_OR_TENANT'
      });
      return res.status(401).json({ error: 'Usuário não encontrado ou inativo' });
    }

    // Log de autenticação bem-sucedida
    logger.info('Acesso autorizado', {
      ...requestContext,
      userId: user.id,
      userName: user.nome,
      userType: user.tipo_usuario,
      tenantId: user.tenant_id,
      tenantName: user.tenant_name,
      tenantPlan: user.tenant_plan
    });

    // Adicionar dados ao request
    req.user = user;
    req.tenantId = user.tenant_id;
    req.tenantCode = user.tenant_code;

    console.log('✅ AUTH MIDDLEWARE CONCLUÍDO - Passando para próximo middleware');
    next();
  } catch (error) {
    // Log detalhado do erro
    logger.error('Falha na autenticação', {
      ...requestContext,
      error: {
        type: error.constructor.name,
        name: error.name,
        message: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      }
    });

    // Respostas específicas por tipo de erro
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expirado' });
    } 
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token inválido' });
    }

    return res.status(500).json({ 
      error: 'Erro interno na autenticação',
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
};

// Middleware para verificar permissões de administrador
const adminMiddleware = (req, res, next) => {
  const requestContext = {
    method: req.method,
    path: req.path,
    userId: req.user.id,
    userName: req.user.nome,
    userType: req.user.tipo_usuario,
    tenantId: req.tenantId,
    timestamp: new Date().toISOString()
  };

  if (req.user.tipo_usuario !== 'administrador') {
    logger.warn('Acesso administrativo negado', {
      ...requestContext,
      reason: 'INSUFFICIENT_PRIVILEGES'
    });
    return res.status(403).json({ error: 'Acesso negado. Apenas administradores.' });
  }

  logger.debug('Acesso administrativo permitido', requestContext);
  next();
};

module.exports = authMiddleware;
module.exports.adminMiddleware = adminMiddleware;