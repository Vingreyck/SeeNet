const { body, param, query } = require('express-validator');

// Validações para tenant
const validateTenantCode = () => {
  return param('codigo')
    .trim()
    .isLength({ min: 3, max: 20 })
    .matches(/^[A-Z0-9]+$/)
    .withMessage('Código da empresa deve ter 3-20 caracteres alfanuméricos maiúsculos');
};

// Validações para usuário
const validateUser = () => {
  return [
    body('nome')
      .trim()
      .isLength({ min: 2, max: 100 })
      .matches(/^[a-zA-ZÀ-ÿ\s]+$/)
      .withMessage('Nome deve ter 2-100 caracteres e conter apenas letras'),
    
    body('email')
      .isEmail()
      .normalizeEmail()
      .isLength({ max: 255 })
      .withMessage('Email inválido'),
    
    body('senha')
      .isLength({ min: 6, max: 128 })
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .withMessage('Senha deve ter 6-128 caracteres, incluindo maiúscula, minúscula e número'),
    
    body('codigoEmpresa')
      .trim()
      .isLength({ min: 3, max: 20 })
      .matches(/^[A-Z0-9]+$/)
      .withMessage('Código da empresa inválido')
  ];
};

// Validações para checkmark
const validateCheckmark = () => {
  return [
    body('categoria_id')
      .isInt({ min: 1 })
      .withMessage('ID da categoria deve ser um número positivo'),
    
    body('titulo')
      .trim()
      .isLength({ min: 2, max: 255 })
      .withMessage('Título deve ter 2-255 caracteres'),
    
    body('descricao')
      .optional()
      .trim()
      .isLength({ max: 1000 })
      .withMessage('Descrição não pode ter mais de 1000 caracteres'),
    
    body('prompt_chatgpt')
      .trim()
      .isLength({ min: 10, max: 5000 })
      .withMessage('Prompt deve ter 10-5000 caracteres'),
    
    body('ordem')
      .optional()
      .isInt({ min: 0, max: 9999 })
      .withMessage('Ordem deve ser um número entre 0 e 9999')
  ];
};

// Validações para paginação
const validatePagination = () => {
  return [
    query('page')
      .optional()
      .isInt({ min: 1, max: 1000 })
      .withMessage('Página deve ser um número entre 1 e 1000'),
    
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage('Limite deve ser um número entre 1 e 100'),
    
    query('busca')
      .optional()
      .trim()
      .isLength({ min: 2, max: 255 })
      .withMessage('Busca deve ter 2-255 caracteres')
  ];
};

// Middleware para verificar tenant nas requisições
const tenantMiddleware = async (req, res, next) => {
  try {
    const tenantCode = req.header('X-Tenant-Code');
    
    if (!tenantCode) {
      return res.status(400).json({ 
        error: 'Código da empresa requerido no header X-Tenant-Code' 
      });
    }

    // Verificar se tenant existe e está ativo
    const { db } = require('../config/database');
    const tenant = await db('tenants')
      .where('codigo', tenantCode.toUpperCase())
      .where('ativo', true)
      .first();

    if (!tenant) {
      return res.status(404).json({ 
        error: 'Empresa não encontrada ou inativa' 
      });
    }

    // Adicionar informações do tenant à requisição
    req.tenant = tenant;
    req.tenantId = tenant.id;
    req.tenantCode = tenant.codigo;

    next();
  } catch (error) {
    logger.error('Erro no middleware de tenant:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
};

module.exports = {
  validateTenantCode,
  validateUser,
  validateCheckmark,
  validatePagination,
  tenantMiddleware
};