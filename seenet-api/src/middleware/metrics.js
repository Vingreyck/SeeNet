const prometheus = require('prom-client');
const logger = require('../config/logger');

// Registrar métricas padrão
prometheus.register.clear();
prometheus.collectDefaultMetrics({ prefix: 'seenet_' });

// Métricas customizadas
const httpRequestDuration = new prometheus.Histogram({
  name: 'seenet_http_request_duration_seconds',
  help: 'Duração das requisições HTTP',
  labelNames: ['method', 'route', 'status_code', 'tenant']
});

const httpRequestsTotal = new prometheus.Counter({
  name: 'seenet_http_requests_total',
  help: 'Total de requisições HTTP',
  labelNames: ['method', 'route', 'status_code', 'tenant']
});

const geminiRequestsTotal = new prometheus.Counter({
  name: 'seenet_gemini_requests_total',
  help: 'Total de requisições para Gemini',
  labelNames: ['status', 'tenant']
});

const activeUsers = new prometheus.Gauge({
  name: 'seenet_active_users',
  help: 'Usuários ativos por tenant',
  labelNames: ['tenant']
});

// Middleware de métricas
const metricsMiddleware = (req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    const route = req.route?.path || req.path;
    const tenant = req.tenantCode || 'unknown';
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode, tenant)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, route, res.statusCode, tenant)
      .inc();
  });
  
  next();
};

// Função para registrar uso do Gemini
const recordGeminiUsage = (tenant, success) => {
  geminiRequestsTotal
    .labels(success ? 'success' : 'error', tenant)
    .inc();
};

// Atualizar usuários ativos periodicamente
const updateActiveUsers = async () => {
  try {
    const { db } = require('../config/database');
    
    const activeUsersData = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.ativo', true)
      .where('usuarios.ultimo_login', '>', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
      .groupBy('tenants.codigo')
      .select('tenants.codigo')
      .count('usuarios.id as count');
    
    // Reset all gauges
    activeUsers.reset();
    
    // Set active users per tenant
    activeUsersData.forEach(({ codigo, count }) => {
      activeUsers.labels(codigo).set(count);
    });
  } catch (error) {
    logger.error('Erro ao atualizar métricas de usuários ativos:', error);
  }
};

// Atualizar métricas a cada 5 minutos
setInterval(updateActiveUsers, 5 * 60 * 1000);

// Endpoint de métricas
const metricsEndpoint = (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
};

module.exports = {
  metricsMiddleware,
  recordGeminiUsage,
  metricsEndpoint,
  updateActiveUsers
};
