const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const sufijo = Date.now();
const correo = `bloqueo-test-${sufijo}@correo.com`;
const password = 'clave12345';

beforeAll(async () => {
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Bloqueo',
    email: correo,
    password,
    acepta_terminos: true,
  });
});

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'bloqueo-test-%'");
  await pool.query("DELETE FROM login_intentos WHERE email LIKE 'bloqueo-test-%'");
  await pool.end();
});

const login = (email, clave) => request(app).post('/api/v1/auth/login').send({ email, password: clave });

describe('Bloqueo temporal tras 5 contraseñas incorrectas', () => {
  it('cuenta los intentos fallidos y bloquea al quinto', async () => {
    for (let esperado = 4; esperado >= 1; esperado--) {
      const res = await login(correo, 'incorrecta1');
      expect(res.statusCode).toBe(401);
      expect(res.body.intentos_restantes).toBe(esperado);
    }

    const quinto = await login(correo, 'incorrecta1');
    expect(quinto.statusCode).toBe(429);
    expect(quinto.body.bloqueado).toBe(true);
    expect(quinto.body.segundos_restantes).toBeGreaterThan(14 * 60);
    expect(quinto.body.segundos_restantes).toBeLessThanOrEqual(15 * 60);
  });

  it('mientras dura el bloqueo rechaza incluso la contraseña correcta', async () => {
    const res = await login(correo, password);
    expect(res.statusCode).toBe(429);
    expect(res.body.token).toBeUndefined();
  });

  it('al terminar el bloqueo permite entrar de nuevo y reinicia el conteo', async () => {
    await pool.query(
      "UPDATE login_intentos SET bloqueado_hasta = now() - interval '1 second' WHERE email = $1",
      [correo]
    );
    const ok = await login(correo, password);
    expect(ok.statusCode).toBe(200);

    const { rows } = await pool.query('SELECT 1 FROM login_intentos WHERE email = $1', [correo]);
    expect(rows).toHaveLength(0);
  });

  it('un acierto antes del límite reinicia el conteo', async () => {
    await login(correo, 'incorrecta1');
    await login(correo, 'incorrecta1');
    expect((await login(correo, password)).statusCode).toBe(200);

    const res = await login(correo, 'incorrecta1');
    expect(res.body.intentos_restantes).toBe(4);
    await pool.query('DELETE FROM login_intentos WHERE email = $1', [correo]);
  });

  it('también bloquea correos que no existen, sin revelar que no están registrados', async () => {
    const inexistente = `bloqueo-test-noexiste-${sufijo}@correo.com`;
    let ultimo;
    for (let i = 0; i < 5; i++) ultimo = await login(inexistente, 'incorrecta1');
    expect(ultimo.statusCode).toBe(429);
  });
});

describe('Acceso de personal de botica', () => {
  const loginPersonal = (email, clave) =>
    request(app).post('/api/v1/auth/login-personal').send({ email, password: clave });

  it('el personal inicia sesión por su propia puerta y recibe el nombre de su botica', async () => {
    const res = await loginPersonal('personal.elna@farmiq.test', 'Personal123');
    expect(res.statusCode).toBe(200);
    expect(res.body.usuario.rol).toBe('personal');
    expect(res.body.usuario.botica_nombre).toBe('Botica Elna');
  });

  it('el personal no puede entrar por el login de clientes', async () => {
    const res = await login('personal.elna@farmiq.test', 'Personal123');
    expect(res.statusCode).toBe(403);
    expect(res.body.token).toBeUndefined();
  });

  it('un cliente no puede entrar por el login de personal', async () => {
    const res = await loginPersonal('cliente.prueba@farmiq.test', 'Cliente123');
    expect(res.statusCode).toBe(403);
    expect(res.body.token).toBeUndefined();
  });
});
