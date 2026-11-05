const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const correo = 'hu14-test-' + Date.now() + '@correo.com';
const password = 'clave12345';
let token;

beforeAll(async () => {
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Perfil',
    email: correo,
    password,
    acepta_terminos: true,
  });
  const login = await request(app).post('/api/v1/auth/login').send({ email: correo, password });
  token = login.body.token;
});

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'hu14-test-%'");
  await pool.end();
});

describe('Perfil de usuario (HU14)', () => {
  it('rechaza ver el perfil sin token', async () => {
    const res = await request(app).get('/api/v1/perfil');
    expect(res.statusCode).toBe(401);
  });

  it('devuelve el perfil del usuario autenticado sin contraseña', async () => {
    const res = await request(app).get('/api/v1/perfil').set('Authorization', 'Bearer ' + token);

    expect(res.statusCode).toBe(200);
    expect(res.body.usuario.email).toBe(correo);
    expect(res.body.usuario.password_hash).toBeUndefined();
  });

  it('actualiza teléfono y dirección sin tocar el nombre', async () => {
    const res = await request(app)
      .patch('/api/v1/perfil')
      .set('Authorization', 'Bearer ' + token)
      .send({ telefono: '999888777', direccion: 'Av. Larco 742' });

    expect(res.statusCode).toBe(200);
    expect(res.body.usuario.telefono).toBe('999888777');
    expect(res.body.usuario.direccion).toBe('Av. Larco 742');
    expect(res.body.usuario.nombre).toBe('Cliente Perfil');
  });

  it('rechaza un teléfono con formato inválido', async () => {
    const res = await request(app)
      .patch('/api/v1/perfil')
      .set('Authorization', 'Bearer ' + token)
      .send({ telefono: '123' });
    expect(res.statusCode).toBe(400);
  });

  it('no permite cambiar el rol ni el correo', async () => {
    const res = await request(app)
      .patch('/api/v1/perfil')
      .set('Authorization', 'Bearer ' + token)
      .send({ rol: 'admin', email: 'otro@correo.com' });
    expect(res.statusCode).toBe(400);

    const perfil = await request(app).get('/api/v1/perfil').set('Authorization', 'Bearer ' + token);
    expect(perfil.body.usuario.rol).toBe('cliente');
    expect(perfil.body.usuario.email).toBe(correo);
  });
});
