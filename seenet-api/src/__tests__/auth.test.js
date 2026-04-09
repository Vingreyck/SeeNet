const request = require('supertest');
const app = require('../src/app'); // exportar o app do server.js

describe('POST /api/auth/login', () => {
  it('retorna 200 e token com credenciais válidas', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('X-Tenant-Code', 'BBNET123')
      .send({ nome: 'David Santos Teles', senha: 'password', codigoEmpresa: 'BBNET123' });

    expect(res.status).toBe(200);
    expect(res.body.data.token).toBeDefined();
  });

  it('retorna 401 com senha errada', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .set('X-Tenant-Code', 'BBNET123')
      .send({ nome: 'David Santos Teles', senha: 'errada', codigoEmpresa: 'BBNET123' });

    expect(res.status).toBe(401);
  });

  it('responde em menos de 3 segundos', async () => {
    const inicio = Date.now();
    await request(app)
      .post('/api/auth/login')
      .set('X-Tenant-Code', 'BBNET123')
      .send({ nome: 'David Santos Teles', senha: 'password', codigoEmpresa: 'BBNET123' });

    expect(Date.now() - inicio).toBeLessThan(3000);
  });
});