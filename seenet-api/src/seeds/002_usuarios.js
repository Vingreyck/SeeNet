const bcrypt = require('bcryptjs');

exports.seed = async function(knex) {
  // Verificar se já existem dados
  const existingUsers = await knex('usuarios').select('id').limit(1);
  if (existingUsers.length > 0) {
    console.log('📊 Usuários já existem, pulando...');
    return;
  }

  // Hash das senhas CORRETAS para PostgreSQL
  const adminPassword = await bcrypt.hash('admin123', 10);
  const tecnicoPassword = await bcrypt.hash('123456', 10);

  console.log('👤 Criando usuários...');

  // Inserir usuários
  await knex('usuarios').insert([
    // Usuários do tenant DEMO
    {
      tenant_id: 1,
      nome: 'Administrador Demo',
      email: 'admin@seenet.com',
      senha: adminPassword,
      tipo_usuario: 'administrador',
      ativo: true
    },
    {
      tenant_id: 1,
      nome: 'Técnico Demo',
      email: 'tecnico@seenet.com',
      senha: tecnicoPassword,
      tipo_usuario: 'tecnico',
      ativo: true
    },
    // Usuários do tenant TECH
    {
      tenant_id: 2,
      nome: 'Admin TechCorp',
      email: 'admin@techcorp.com',
      senha: adminPassword,
      tipo_usuario: 'administrador',
      ativo: true
    },
    {
      tenant_id: 2,
      nome: 'Wendel',
      email: 'wendel@techcorp.com',
      senha: tecnicoPassword,
      tipo_usuario: 'administrador',
      ativo: true
    },
    {
      tenant_id: 2,
      nome: 'Maria Santos',
      email: 'maria@techcorp.com',
      senha: tecnicoPassword,
      tipo_usuario: 'tecnico',
      ativo: true
    }
  ]);

  console.log('✅ Usuários criados para PostgreSQL');
};