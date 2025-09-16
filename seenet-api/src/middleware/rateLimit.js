const rateLimit = require('express-rate-limit');
const { db } = require('../config/database');
const logger = require('../config/logger');

// Rate limit por tenant
const createTenantRateLimit = (windowMs, max, message) => {
  return rateLimit({
    windowMs,
    max,
    message: { error: message },
    keyGenerator: (req) => {
      // Combinar IP + Tenant para rate limiting isolado
      return `${req.ip}-${req.tenantCode || 'no-tenant'}`;
    },
    handler: (req, res) => {
      logger.warn(`Rate limit atingido: ${req.ip} - Tenant: ${req.tenantCode}`);
      res.status(429).json({ 
        error: message,
        retryAfter: Math.ceil(windowMs / 1000)
      });
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
};

// Rate limit para API Gemini (por tenant)
const createGeminiRateLimit = () => {
  const usage = new Map();
  
  return async (req, res, next) => {
    try {
      const tenantCode = req.tenantCode;
      const agora = Date.now();
      const janela = 60 * 1000; // 1 minuto
      
      if (!tenantCode) {
        return next();
      }

      // Buscar configurações do tenant
      const tenant = await db('tenants')
        .where('codigo', tenantCode)
        .first();

      if (!tenant) {
        return res.status(404).json({ error: 'Tenant não encontrado' });
      }

      const config = JSON.parse(tenant.configuracoes || '{}');
      const limite = config.gemini_requests_per_minute || 10;

      // Verificar uso atual
      const chave = `gemini-${tenantCode}`;
      const usoAtual = usage.get(chave) || { count: 0, window: agora };

      // Reset se janela expirou
      if (agora - usoAtual.window > janela) {
        usoAtual.count = 0;
        usoAtual.window = agora;
      }

      // Verificar limite
      if (usoAtual.count >= limite) {
        return res.status(429).json({
          error: `Limite de ${limite} requisições por minuto atingido`,
          retryAfter: Math.ceil((janela - (agora - usoAtual.window)) / 1000)
        });
      }

      // Incrementar contador
      usoAtual.count++;
      usage.set(chave, usoAtual);

      next();
    } catch (error) {
      logger.error('Erro no rate limit Gemini:', error);
      next(); // Permitir em caso de erro
    }
  };
};

// Diferentes níveis de rate limiting
const rateLimits = {
  // Geral para API
  general: createTenantRateLimit(
    15 * 60 * 1000, // 15 minutos
    100, // 100 requests
    'Muitas requisições. Tente novamente em 15 minutos.'
  ),

  // Autenticação (mais restritivo)
  auth: createTenantRateLimit(
    15 * 60 * 1000, // 15 minutos
    10, // 10 tentativas
    'Muitas tentativas de login. Tente novamente em 15 minutos.'
  ),

  // Diagnósticos (limitado por plano)
  diagnostics: createTenantRateLimit(
    60 * 60 * 1000, // 1 hora
    50, // 50 diagnósticos por hora
    'Limite de diagnósticos por hora atingido.'
  ),

  // Upload de arquivos
  upload: createTenantRateLimit(
    60 * 60 * 1000, // 1 hora
    20, // 20 uploads por hora
    'Limite de uploads por hora atingido.'
  ),

  // Gemini API
  gemini: createGeminiRateLimit()
};

module.exports = rateLimits;
