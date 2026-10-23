const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const correo = 'hu01-test-' + Date.now() + '@correo.com';

const datosValidos = {
  nombre: 'Cliente de Prueba',
  email: correo,
  telefono: '987654321',
  password: 'clave12345',
  acepta_terminos: true,
};

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'hu01-test-%'");
  await pool.end();
});

describe('POST /api/v1/auth/registro (HU01)', () => {
  it('registra un cliente nuevo y no devuelve la contraseña', async () => {
    const res = await request(app).post('/api/v1/auth/registro').send(datosValidos);

    expect(res.statusCode).toBe(201);
    expect(res.body.usuario.email).toBe(correo);
    expect(res.body.usuario.rol).toBe('cliente');
    expect(res.body.usuario.password_hash).toBeUndefined();
    expect(res.body.usuario.password).toBeUndefined();
  });

  it('guarda la contraseña cifrada y no en texto plano', async () => {
    const { rows } = await pool.query(
      'SELECT password_hash FROM usuarios WHERE email = $1',
      [correo]
    );

    expect(rows[0].password_hash).not.toBe(datosValidos.password);
    expect(rows[0].password_hash.startsWith('$2')).toBe(true);
  });

  it('rechaza un correo ya registrado con 409', async () => {
    const res = await request(app).post('/api/v1/auth/registro').send(datosValidos);
    expect(res.statusCode).toBe(409);
  });

  it('rechaza una contraseña de menos de 8 caracteres', async () => {
    const res = await request(app)
      .post('/api/v1/auth/registro')
      .send({ ...datosValidos, email: 'hu01-test-corta@correo.com', password: '1234567' });
    expect(res.statusCode).toBe(400);
  });

  it('rechaza un correo con formato inválido', async () => {
    const res = await request(app)
      .post('/api/v1/auth/registro')
      .send({ ...datosValidos, email: 'esto-no-es-un-correo' });
    expect(res.statusCode).toBe(400);
  });

  it('rechaza si no se aceptan los términos', async () => {
    const res = await request(app)
      .post('/api/v1/auth/registro')
      .send({ ...datosValidos, email: 'hu01-test-terminos@correo.com', acepta_terminos: false });
    expect(res.statusCode).toBe(400);
  });

  it('ignora un rol enviado por el cliente (siempre queda cliente)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/registro')
      .send({ ...datosValidos, email: 'hu01-test-rol@correo.com', rol: 'admin' });

    expect(res.statusCode).toBe(201);
    expect(res.body.usuario.rol).toBe('cliente');
  });
});
