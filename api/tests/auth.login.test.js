const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const correo = 'hu02-test-' + Date.now() + '@correo.com';
const password = 'clave12345';

beforeAll(async () => {
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Login',
    email: correo,
    password,
    acepta_terminos: true,
  });
});

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'hu02-test-%'");
  await pool.end();
});

describe('POST /api/v1/auth/login (HU02)', () => {
  it('inicia sesión y devuelve un token y el usuario sin contraseña', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: correo, password });

    expect(res.statusCode).toBe(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.usuario.email).toBe(correo);
    expect(res.body.usuario.password_hash).toBeUndefined();
  });

  it('acepta el correo con mayúsculas', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: correo.toUpperCase(), password });
    expect(res.statusCode).toBe(200);
  });

  it('rechaza una contraseña incorrecta con 401', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: correo, password: 'incorrecta1' });
    expect(res.statusCode).toBe(401);
  });

  it('rechaza un correo inexistente con el mismo mensaje', async () => {
    const mala = await request(app).post('/api/v1/auth/login').send({ email: correo, password: 'incorrecta1' });
    const inexistente = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'no-existe-hu02@correo.com', password });

    expect(inexistente.statusCode).toBe(401);
    expect(inexistente.body.error).toBe(mala.body.error);
  });

  it('rechaza datos con formato inválido con 400', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: 'no-es-correo', password: '' });
    expect(res.statusCode).toBe(400);
  });
});

describe('GET /api/v1/auth/yo (ruta protegida)', () => {
  it('rechaza una petición sin token', async () => {
    const res = await request(app).get('/api/v1/auth/yo');
    expect(res.statusCode).toBe(401);
  });

  it('rechaza un token falso', async () => {
    const res = await request(app).get('/api/v1/auth/yo').set('Authorization', 'Bearer token.falso.aqui');
    expect(res.statusCode).toBe(401);
  });

  it('acepta un token válido y devuelve el usuario', async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: correo, password });
    const res = await request(app)
      .get('/api/v1/auth/yo')
      .set('Authorization', 'Bearer ' + login.body.token);

    expect(res.statusCode).toBe(200);
    expect(res.body.usuario.rol).toBe('cliente');
  });
});
