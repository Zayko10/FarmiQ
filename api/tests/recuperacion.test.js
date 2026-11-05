const crypto = require('crypto');
const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const correo = 'hu13-test-' + Date.now() + '@correo.com';
const passwordVieja = 'clave12345';
const passwordNueva = 'nuevaclave123';

function hash(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function crearToken(minutos) {
  const { rows } = await pool.query('SELECT id FROM usuarios WHERE email = $1', [correo]);
  const token = crypto.randomBytes(32).toString('hex');
  await pool.query(
    "INSERT INTO password_resets (usuario_id, token_hash, expira_en) VALUES ($1, $2, now() + ($3 || ' minutes')::interval)",
    [rows[0].id, hash(token), String(minutos)]
  );
  return token;
}

beforeAll(async () => {
  jest.spyOn(console, 'log').mockImplementation(() => {});
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Recupera',
    email: correo,
    password: passwordVieja,
    acepta_terminos: true,
  });
});

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'hu13-test-%'");
  await pool.end();
});

describe('Recuperación de contraseña (HU13)', () => {
  it('responde igual para un correo registrado y uno inexistente', async () => {
    const existe = await request(app).post('/api/v1/auth/olvide-password').send({ email: correo });
    const noExiste = await request(app)
      .post('/api/v1/auth/olvide-password')
      .send({ email: 'no-existe-hu13@correo.com' });

    expect(existe.statusCode).toBe(200);
    expect(noExiste.statusCode).toBe(200);
    expect(existe.body.mensaje).toBe(noExiste.body.mensaje);
  });

  it('guarda solo el hash del token al solicitar la recuperación', async () => {
    const { rows } = await pool.query(
      'SELECT token_hash FROM password_resets pr JOIN usuarios u ON u.id = pr.usuario_id WHERE u.email = $1',
      [correo]
    );
    expect(rows.length).toBeGreaterThan(0);
    expect(rows[0].token_hash).toHaveLength(64);
  });

  it('rechaza un correo con formato inválido', async () => {
    const res = await request(app).post('/api/v1/auth/olvide-password').send({ email: 'no-es-correo' });
    expect(res.statusCode).toBe(400);
  });

  it('rechaza un token inexistente', async () => {
    const res = await request(app)
      .post('/api/v1/auth/restablecer-password')
      .send({ token: 'token-falso', password: passwordNueva });
    expect(res.statusCode).toBe(400);
  });

  it('rechaza un token vencido', async () => {
    const token = await crearToken(-5);
    const res = await request(app)
      .post('/api/v1/auth/restablecer-password')
      .send({ token, password: passwordNueva });
    expect(res.statusCode).toBe(400);
  });

  it('rechaza una contraseña nueva de menos de 8 caracteres', async () => {
    const token = await crearToken(60);
    const res = await request(app)
      .post('/api/v1/auth/restablecer-password')
      .send({ token, password: '1234567' });
    expect(res.statusCode).toBe(400);
  });

  it('restablece la contraseña, permite el login nuevo y bloquea reutilizar el token', async () => {
    const token = await crearToken(60);

    const ok = await request(app)
      .post('/api/v1/auth/restablecer-password')
      .send({ token, password: passwordNueva });
    expect(ok.statusCode).toBe(200);

    const loginNuevo = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: correo, password: passwordNueva });
    expect(loginNuevo.statusCode).toBe(200);

    const loginViejo = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: correo, password: passwordVieja });
    expect(loginViejo.statusCode).toBe(401);

    const reuso = await request(app)
      .post('/api/v1/auth/restablecer-password')
      .send({ token, password: 'otraclave123' });
    expect(reuso.statusCode).toBe(400);
  });
});
