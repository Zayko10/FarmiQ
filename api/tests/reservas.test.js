const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const sufijo = Date.now();
const password = 'clave12345';
const TARJETA_OK = { metodo: 'tarjeta', numero_tarjeta: '4111 1111 1111 1111', vencimiento: '12/99', cvv: '123' };

let token;
let boticaId;
let ibuprofeno; // Ibuprofeno MK en Botica Elna (stock 30)
let cozaar; // Cozaar en Botica Elna (stock 4)
const originales = {};

const con = (req) => req.set('Authorization', 'Bearer ' + token);
const inventario = async (medId) =>
  (
    await pool.query(
      'SELECT stock, stock_reservado FROM inventario WHERE botica_id = $1 AND medicamento_id = $2',
      [boticaId, medId]
    )
  ).rows[0];
const reservar = (medicamento_id, cantidad = 1) =>
  con(request(app).post('/api/v1/reservas')).send({ botica_id: boticaId, medicamento_id, cantidad });

async function idDe(nombre) {
  return (await pool.query('SELECT id FROM medicamentos WHERE nombre = $1', [nombre])).rows[0].id;
}

beforeAll(async () => {
  const email = `reservas-test-${sufijo}@correo.com`;
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Reservas',
    email,
    password,
    acepta_terminos: true,
  });
  token = (await request(app).post('/api/v1/auth/login').send({ email, password })).body.token;

  boticaId = (await pool.query("SELECT id FROM boticas WHERE nombre = 'Botica Elna'")).rows[0].id;
  ibuprofeno = await idDe('Ibuprofeno MK');
  cozaar = await idDe('Cozaar');
  originales[ibuprofeno] = await inventario(ibuprofeno);
  originales[cozaar] = await inventario(cozaar);
});

afterAll(async () => {
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'reservas-test-%'"); // borra sus reservas
  for (const [medId, o] of Object.entries(originales)) {
    await pool.query(
      'UPDATE inventario SET stock = $1, stock_reservado = $2 WHERE botica_id = $3 AND medicamento_id = $4',
      [o.stock, o.stock_reservado, boticaId, medId]
    );
  }
  await pool.end();
});

describe('Reservas con plazo de pago', () => {
  it('exige sesión iniciada', async () => {
    const res = await request(app).post('/api/v1/reservas').send({});
    expect(res.statusCode).toBe(401);
  });

  it('separa el stock por 15 minutos y lo descuenta de la disponibilidad', async () => {
    const antes = await inventario(ibuprofeno);
    const res = await reservar(ibuprofeno, 2);

    expect(res.statusCode).toBe(201);
    expect(res.body.minutos_para_pagar).toBe(15);
    expect(res.body.reserva.estado).toBe('pendiente_pago');
    expect(res.body.reserva.segundos_restantes).toBeGreaterThan(14 * 60);
    expect(res.body.reserva.segundos_restantes).toBeLessThanOrEqual(15 * 60);
    expect(res.body.reserva.total).toBeCloseTo(res.body.reserva.precio_unitario * 2, 2);
    expect(res.body.reserva.codigo).toBeNull(); // el código de retiro se entrega al pagar

    const despues = await inventario(ibuprofeno);
    expect(despues.stock).toBe(antes.stock);
    expect(despues.stock_reservado).toBe(antes.stock_reservado + 2);

    const disp = await request(app).get(`/api/v1/medicamentos/${ibuprofeno}/disponibilidad`);
    const elna = disp.body.boticas.find((b) => String(b.id) === String(boticaId));
    expect(elna.stock).toBe(antes.stock - antes.stock_reservado - 2);

    await con(request(app).post(`/api/v1/reservas/${res.body.reserva.id}/cancelar`));
  });

  it('rechaza una cantidad mayor al stock disponible', async () => {
    const res = await reservar(cozaar, 5); // Cozaar tiene 4 en Botica Elna
    expect(res.statusCode).toBe(409);
    expect(res.body.disponible).toBe(4);
  });

  it('rechaza cantidades inválidas y productos que la botica no vende', async () => {
    expect((await reservar(ibuprofeno, 0)).statusCode).toBe(400);
    expect((await reservar(ibuprofeno, 6)).statusCode).toBe(400);
    expect((await reservar(999999, 1)).statusCode).toBe(404);
  });

  it('libera el stock cuando se vence el plazo de pago', async () => {
    const antes = await inventario(ibuprofeno);
    const nueva = await reservar(ibuprofeno, 3);
    expect((await inventario(ibuprofeno)).stock_reservado).toBe(antes.stock_reservado + 3);

    // Se simula que pasaron los 15 minutos
    await pool.query("UPDATE reservas SET expira_en = now() - interval '1 second' WHERE id = $1", [
      nueva.body.reserva.id,
    ]);

    const lista = await con(request(app).get('/api/v1/reservas'));
    const reserva = lista.body.reservas.find((r) => r.id === nueva.body.reserva.id);
    expect(reserva.estado).toBe('expirada');
    expect(reserva.segundos_restantes).toBe(0);
    expect((await inventario(ibuprofeno)).stock_reservado).toBe(antes.stock_reservado);
  });

  it('no deja pagar una reserva vencida', async () => {
    const nueva = await reservar(ibuprofeno, 1);
    await pool.query("UPDATE reservas SET expira_en = now() - interval '1 second' WHERE id = $1", [
      nueva.body.reserva.id,
    ]);

    const res = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/pagar`)).send(TARJETA_OK);
    expect(res.statusCode).toBe(410);
    expect(res.body.estado).toBe('expirada');
  });

  it('al pagar a tiempo descuenta el stock y entrega el código de retiro', async () => {
    const antes = await inventario(ibuprofeno);
    const nueva = await reservar(ibuprofeno, 2);

    const pago = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/pagar`)).send(TARJETA_OK);
    expect(pago.statusCode).toBe(200);
    expect(pago.body.reserva.estado).toBe('pagada');
    expect(pago.body.reserva.codigo).toMatch(/^[A-Z0-9]{6}$/);
    expect(pago.body.reserva.metodo_pago).toBe('Tarjeta •••• 1111');

    const despues = await inventario(ibuprofeno);
    expect(despues.stock).toBe(antes.stock - 2);
    expect(despues.stock_reservado).toBe(antes.stock_reservado);

    const otraVez = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/pagar`)).send(TARJETA_OK);
    expect(otraVez.statusCode).toBe(409);
  });

  it('si el pago es rechazado la reserva sigue pendiente y con su stock separado', async () => {
    const nueva = await reservar(ibuprofeno, 1);
    const rechazo = { ...TARJETA_OK, numero_tarjeta: '4111111111110000' };

    const pago = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/pagar`)).send(rechazo);
    expect(pago.statusCode).toBe(402);

    const detalle = await con(request(app).get(`/api/v1/reservas/${nueva.body.reserva.id}`));
    expect(detalle.body.reserva.estado).toBe('pendiente_pago');

    await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/cancelar`));
  });

  it('valida los datos de pago', async () => {
    const nueva = await reservar(ibuprofeno, 1);
    const id = nueva.body.reserva.id;

    const sinMetodo = await con(request(app).post(`/api/v1/reservas/${id}/pagar`)).send({});
    const tarjetaCorta = await con(request(app).post(`/api/v1/reservas/${id}/pagar`)).send({ ...TARJETA_OK, numero_tarjeta: '123' });
    const yapeMalo = await con(request(app).post(`/api/v1/reservas/${id}/pagar`)).send({ metodo: 'yape', celular: '123' });
    expect(sinMetodo.statusCode).toBe(400);
    expect(tarjetaCorta.statusCode).toBe(400);
    expect(yapeMalo.statusCode).toBe(400);

    const yape = await con(request(app).post(`/api/v1/reservas/${id}/pagar`)).send({ metodo: 'yape', celular: '987654321' });
    expect(yape.statusCode).toBe(200);
    expect(yape.body.reserva.metodo_pago).toBe('Yape 9•••••321');
  });

  it('cancelar una reserva pendiente devuelve el stock al instante', async () => {
    const antes = await inventario(ibuprofeno);
    const nueva = await reservar(ibuprofeno, 2);

    const res = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/cancelar`));
    expect(res.statusCode).toBe(200);
    expect(res.body.reserva.estado).toBe('cancelada');
    expect((await inventario(ibuprofeno)).stock_reservado).toBe(antes.stock_reservado);

    const otraVez = await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/cancelar`));
    expect(otraVez.statusCode).toBe(409);
  });

  it('limita las reservas pendientes por cliente', async () => {
    const creadas = [];
    for (let i = 0; i < 3; i++) creadas.push((await reservar(ibuprofeno, 1)).body.reserva);
    const cuarta = await reservar(ibuprofeno, 1);
    expect(cuarta.statusCode).toBe(409);

    for (const r of creadas) await con(request(app).post(`/api/v1/reservas/${r.id}/cancelar`));
  });

  it('un cliente no ve las reservas de otro', async () => {
    const nueva = await reservar(ibuprofeno, 1);
    const email = `reservas-test-otro-${sufijo}@correo.com`;
    await request(app).post('/api/v1/auth/registro').send({ nombre: 'Otro', email, password, acepta_terminos: true });
    const otro = (await request(app).post('/api/v1/auth/login').send({ email, password })).body.token;

    const res = await request(app)
      .get(`/api/v1/reservas/${nueva.body.reserva.id}`)
      .set('Authorization', 'Bearer ' + otro);
    expect(res.statusCode).toBe(404);

    await con(request(app).post(`/api/v1/reservas/${nueva.body.reserva.id}/cancelar`));
  });
});
