const formatResponse = (req, res, next) => {
  // Wrapper para res.json que garante estrutura padronizada
  const originalJson = res.json.bind(res);
  
  res.json = (data) => {
    // Se já está no formato correto, enviar direto
    if (data && typeof data === 'object' && 'success' in data) {
      return originalJson(data);
    }
    
    // Formatar resposta de sucesso
    return originalJson({
      success: true,
      data: data
    });
  };
  
  next();
};

const formatError = (err, req, res, next) => {
  console.error('Error:', err);
  
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Erro interno do servidor';
  
  res.status(statusCode).json({
    success: false,
    error: message,
    details: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
};

module.exports = { formatResponse, formatError };