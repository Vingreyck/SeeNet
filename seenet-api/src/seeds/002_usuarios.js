const bcrypt = require('bcryptjs');

exports.seed = async function(knex) {
  // Hash das senhas
  const adminPassword = await bcrypt.hash('admin123', 12);
  const tecnicoPassword = await bcrypt.hash('123456', 12);

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

  console.log('✅ Usuários criados');
};