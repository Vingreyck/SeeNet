const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const logger = require('../config/logger');

const authMiddleware = async (req, res, next) => {
  try {
    console.log('🔐 === AUTH MIDDLEWARE INICIADO ===');
    console.log('📍 Rota:', req.method, req.path);
    
    const token = req.header('Authorization')?.replace('Bearer ', '');
    const tenantCode = req.header('X-Tenant-Code');

    console.log('🔑 Token presente?', !!token);
    console.log('🏢 Tenant Code:', tenantCode || 'AUSENTE');

    if (!token) {
      console.log('❌ Token ausente');
      return res.status(401).json({ error: 'Token de acesso requerido' });
    }

    if (!tenantCode) {
      console.log('❌ Tenant Code ausente');
      return res.status(400).json({ error: 'Código da empresa requerido' });
    }

    // Verificar token
    console.log('🔍 Verificando token JWT...');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('✅ Token decodificado:', { userId: decoded.userId, tenantId: decoded.tenantId });
    
    // Buscar usuário e tenant
    console.log('🔍 Buscando usuário no banco...');
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.id', decoded.userId)
      .where('tenants.codigo', tenantCode)
      .where('usuarios.ativo', true)
      .where('tenants.ativo', true)
      .select(
        'usuarios.*',
        'tenants.id as tenant_id',
        'tenants.codigo as tenant_code',
        'tenants.nome as tenant_name',
        'tenants.plano as tenant_plan'
      )
      .first();

    if (!user) {
      console.log('❌ Usuário não encontrado ou inativo');
      return res.status(401).json({ error: 'Usuário não encontrado ou inativo' });
    }
    
    console.log('✅ Usuário encontrado:', user.nome, '- Tenant:', user.tenant_name);

    // Adicionar informações do usuário e tenant à requisição
    req.user = user;
    req.tenantId = user.tenant_id;
    req.tenantCode = user.tenant_code;

    console.log('✅ AUTH MIDDLEWARE CONCLUÍDO - Passando para próximo middleware');
    next();
  } catch (error) {
    console.error('❌ ERRO NO AUTH MIDDLEWARE:', error.message);
    logger.error('Erro na autenticação:', error);
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expirado' });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Token inválido' });
    }

    res.status(500).json({ error: 'Erro interno do servidor' });
  }
};

// Middleware para verificar se é admin
const adminMiddleware = (req, res, next) => {
  if (req.user.tipo_usuario !== 'administrador') {
    return res.status(403).json({ error: 'Acesso negado. Apenas administradores.' });
  }
  next();
};

module.exports = authMiddleware;
module.exports.adminMiddleware = adminMiddleware;