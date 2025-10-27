const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const logger = require('../config/logger');


const authMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    const tenantCode = req.header('X-Tenant-Code');

    if (!token) {
      return res.status(401).json({ error: 'Token de acesso requerido' });
    }

    if (!tenantCode) {
      return res.status(400).json({ error: 'Código da empresa requerido' });
    }

    // Verificar token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Buscar usuário e tenant
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
      return res.status(401).json({ error: 'Usuário não encontrado ou inativo' });
    }
    

    // Adicionar informações do usuário e tenant à requisição
    req.user = user;
    req.tenantId = user.tenant_id;
    req.tenantCode = user.tenant_code;

    next();
  } catch (error) {
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