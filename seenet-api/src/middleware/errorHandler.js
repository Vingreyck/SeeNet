const logger = require('../config/logger');

const errorHandler = (error, req, res, next) => {
  // Log do erro
  logger.error('Erro na aplicação:', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    tenantCode: req.tenantCode,
    userId: req.user?.id
  });

  // Não vazar detalhes em produção
  const isDevelopment = process.env.NODE_ENV === 'development';

  // Erros conhecidos
  if (error.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Dados inválidos',
      details: isDevelopment ? error.details : undefined
    });
  }

  if (error.name === 'UnauthorizedError' || error.code === 'UNAUTHORIZED') {
    return res.status(401).json({
      error: 'Não autorizado'
    });
  }

  if (error.name === 'ForbiddenError' || error.code === 'FORBIDDEN') {
    return res.status(403).json({
      error: 'Acesso negado'
    });
  }

  if (error.name === 'NotFoundError' || error.code === 'NOT_FOUND') {
    return res.status(404).json({
      error: 'Recurso não encontrado'
    });
  }

  if (error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
    return res.status(409).json({
      error: 'Dados duplicados. Recurso já existe.'
    });
  }

  if (error.code === 'SQLITE_CONSTRAINT_FOREIGNKEY') {
    return res.status(400).json({
      error: 'Referência inválida. Verifique os dados relacionados.'
    });
  }

  // Erro genérico
  res.status(500).json({
    error: 'Erro interno do servidor',
    message: isDevelopment ? error.message : 'Algo deu errado',
    stack: isDevelopment ? error.stack : undefined
  });
};

module.exports = errorHandler;