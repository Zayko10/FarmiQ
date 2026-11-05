const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const sufijo = Date.now();
let tokenElna;
let tokenSaludTotal;
let tokenCliente;
let boticaElna;
let simeticona; // Simeticona MK, producto que solo usa esta suite
let original;

const con = (token) => (req) => req.set('Authorization', 'Bearer ' + token);
const elna = (req) => con(tokenElna)(req);

async function loginPersonal(email) {
  const res = await request(app).post('/api/v1/auth/login-personal').send({ email, password: 'Personal123' });
  return res.body.token;
}

beforeAll(async () => {
  tokenElna = await loginPersonal('personal.elna@farmiq.test');
  tokenSaludTotal = await loginPersonal('personal.saludtotal@farmiq.test');
  tokenCliente = (
    await request(app).post('/api/v1/auth/login').send({ email: 'cliente.prueba@farmiq.test', password: 'Cliente123' })
  ).body.token;

  boticaElna = (await pool.query("SELECT id FROM boticas WHERE nombre = 'Botica Elna'")).rows[0].id;
  simeticona = (await pool.query("SELECT id FROM medicamentos WHERE nombre = 'Simeticona MK'")).rows[0].id;
  original = (
    await pool.query('SELECT stock, stock_reservado, precio, actualizado_en FROM inventario WHERE botica_id = $1 AND medicamento_id = $2', [
      boticaElna,
      simeticona,
    ])
  ).rows[0];
});

afterAll(async () => {
  await pool.query(
    'UPDATE inventario SET stock = $1, stock_reservado = $2, precio = $3, actualizado_en = $4 WHERE botica_id = $5 AND medicamento_id = $6',
    [original.stock, original.stock_reservado, original.precio, original.actualizado_en, boticaElna, simeticona]
  );
  await pool.query("DELETE FROM medicamentos WHERE nombre LIKE 'TEST Producto panel%'");
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'panel-test-%'");
  await pool.end();
});

describe('Panel de la botica: acceso', () => {
  it('sin sesión responde 401', async () => {
    expect((await request(app).get('/api/v1/panel/resumen')).statusCode).toBe(401);
  });

  it('un cliente no puede usar el panel (403)', async () => {
    const res = await con(tokenCliente)(request(app).get('/api/v1/panel/resumen'));
    expect(res.statusCode).toBe(403);
  });

  it('el personal ve el resumen de su botica', async () => {
    const res = await elna(request(app).get('/api/v1/panel/resumen'));
    expect(res.statusCode).toBe(200);
    expect(res.body.botica.nombre).toBe('Botica Elna');
    expect(res.body.inventario.productos).toBeGreaterThan(30);
    expect(res.body.inventario.desactualizados).toBeGreaterThanOrEqual(2); // Glucophage y Metformina MK (30 h)
  });
});

describe('Panel de la botica: inventario (HU27)', () => {
  it('lista y filtra el inventario sin tildes', async () => {
    const res = await elna(request(app).get('/api/v1/panel/inventario').query({ q: 'SIMETICONA' }));
    expect(res.statusCode).toBe(200);
    expect(res.body.productos).toHaveLength(1);
    expect(res.body.productos[0].nombre).toBe('Simeticona MK');
  });

  it('filtra los productos desactualizados (más de 24 h)', async () => {
    const res = await elna(request(app).get('/api/v1/panel/inventario').query({ filtro: 'desactualizados' }));
    const nombres = res.body.productos.map((p) => p.nombre);
    expect(nombres).toEqual(expect.arrayContaining(['Glucophage', 'Metformina MK']));
    res.body.productos.forEach((p) => expect(p.desactualizado).toBe(true));
  });

  it('actualiza stock y precio y refresca la hora de actualización', async () => {
    const res = await elna(request(app).patch(`/api/v1/panel/inventario/${simeticona}`)).send({ stock: 7, precio: 8.5 });
    expect(res.statusCode).toBe(200);
    expect(res.body.producto.stock).toBe(7);
    expect(res.body.producto.precio).toBe(8.5);
    expect(res.body.producto.minutos_desde_actualizacion).toBeLessThanOrEqual(1);
    expect(res.body.producto.desactualizado).toBe(false);
  });

  it('rechaza valores negativos o un cuerpo vacío', async () => {
    expect((await elna(request(app).patch(`/api/v1/panel/inventario/${simeticona}`)).send({ stock: -1 })).statusCode).toBe(400);
    expect((await elna(request(app).patch(`/api/v1/panel/inventario/${simeticona}`)).send({})).statusCode).toBe(400);
  });

  it('no deja bajar el stock por debajo de lo reservado por clientes', async () => {
    await pool.query('UPDATE inventario SET stock = 10, stock_reservado = 3 WHERE botica_id = $1 AND medicamento_id = $2', [
      boticaElna,
      simeticona,
    ]);
    const res = await elna(request(app).patch(`/api/v1/panel/inventario/${simeticona}`)).send({ stock: 2 });
    expect(res.statusCode).toBe(409);
    expect(res.body.stock_reservado).toBe(3);

    const ok = await elna(request(app).patch(`/api/v1/panel/inventario/${simeticona}`)).send({ stock: 3 });
    expect(ok.statusCode).toBe(200);
  });

  it('responde 404 si el producto no está en el inventario de la botica', async () => {
    const res = await elna(request(app).patch('/api/v1/panel/inventario/999999')).send({ stock: 5 });
    expect(res.statusCode).toBe(404);
  });
});

describe('Panel de la botica: productos nuevos', () => {
  const nuevo = {
    nombre: 'TEST Producto panel',
    principio_activo: 'Principio de prueba',
    concentracion: '10 mg',
    presentacion: 'Tabletas x 10',
    categoria: 'Dolor y fiebre',
    es_generico: true,
    requiere_receta: false,
    dosis_referencial: 'Adultos: 1 tableta al día.',
    indicaciones: 'Producto de prueba.',
    stock: 12,
    precio: 3.5,
  };

  it('crea un producto en el catálogo y en el inventario de la botica', async () => {
    const res = await elna(request(app).post('/api/v1/panel/medicamentos')).send(nuevo);
    expect(res.statusCode).toBe(201);
    expect(res.body.producto.stock).toBe(12);

    const busqueda = await request(app).get('/api/v1/medicamentos').query({ q: 'TEST Producto panel' });
    expect(busqueda.body.resultados.map((m) => m.nombre)).toContain('TEST Producto panel');

    const id = res.body.producto.medicamento_id;
    const detalle = await request(app).get(`/api/v1/medicamentos/${id}`);
    expect(detalle.body.ficha.disponible).toBe(true);
    expect(detalle.body.ficha.indicaciones).toBe('Producto de prueba.');
  });

  it('no permite duplicar nombre + concentración + presentación', async () => {
    const res = await elna(request(app).post('/api/v1/panel/medicamentos')).send(nuevo);
    expect(res.statusCode).toBe(409);
  });

  it('valida los campos obligatorios', async () => {
    const res = await elna(request(app).post('/api/v1/panel/medicamentos')).send({ ...nuevo, nombre: '', precio: -2 });
    expect(res.statusCode).toBe(400);
  });

  it('otra botica puede encontrar el producto en el catálogo y agregarlo a su inventario', async () => {
    const cat = await con(tokenSaludTotal)(request(app).get('/api/v1/panel/catalogo').query({ q: 'TEST Producto panel' }));
    expect(cat.statusCode).toBe(200);
    expect(cat.body.productos).toHaveLength(1);

    const id = cat.body.productos[0].medicamento_id;
    const agregar = await con(tokenSaludTotal)(request(app).post('/api/v1/panel/inventario')).send({
      medicamento_id: id,
      stock: 5,
      precio: 4,
    });
    expect(agregar.statusCode).toBe(201);

    const repetido = await con(tokenSaludTotal)(request(app).post('/api/v1/panel/inventario')).send({
      medicamento_id: id,
      stock: 5,
      precio: 4,
    });
    expect(repetido.statusCode).toBe(409);
  });

  it('el personal puede completar la ficha técnica de un producto que vende', async () => {
    const id = (await pool.query("SELECT id FROM medicamentos WHERE nombre = 'TEST Producto panel'")).rows[0].id;
    const res = await elna(request(app).patch(`/api/v1/panel/medicamentos/${id}/ficha`)).send({
      efectos_adversos: 'Ninguno conocido (prueba).',
    });
    expect(res.statusCode).toBe(200);

    const detalle = await request(app).get(`/api/v1/medicamentos/${id}`);
    expect(detalle.body.ficha.efectos_adversos).toBe('Ninguno conocido (prueba).');
  });
});

describe('Panel de la botica: reservas y entrega', () => {
  it('registra la entrega de una reserva pagada con su código', async () => {
    const email = `panel-test-${sufijo}@correo.com`;
    await request(app).post('/api/v1/auth/registro').send({
      nombre: 'Cliente Panel',
      email,
      password: 'clave12345',
      acepta_terminos: true,
    });
    const token = (await request(app).post('/api/v1/auth/login').send({ email, password: 'clave12345' })).body.token;

    await pool.query('UPDATE inventario SET stock = 20, stock_reservado = 0 WHERE botica_id = $1 AND medicamento_id = $2', [
      boticaElna,
      simeticona,
    ]);

    const reserva = await con(token)(request(app).post('/api/v1/reservas')).send({
      botica_id: boticaElna,
      medicamento_id: simeticona,
      cantidad: 1,
    });
    expect(reserva.statusCode).toBe(201);

    const pendientes = await elna(request(app).get('/api/v1/panel/reservas').query({ estado: 'pendiente_pago' }));
    expect(pendientes.body.reservas.map((r) => r.id)).toContain(reserva.body.reserva.id);

    const pago = await con(token)(request(app).post(`/api/v1/reservas/${reserva.body.reserva.id}/pagar`)).send({
      metodo: 'plin',
      celular: '987654321',
    });
    const codigo = pago.body.reserva.codigo;

    const entrega = await elna(request(app).post('/api/v1/panel/reservas/entregar')).send({ codigo: codigo.toLowerCase() });
    expect(entrega.statusCode).toBe(200);
    expect(entrega.body.reserva.estado).toBe('entregada');

    const repetida = await elna(request(app).post('/api/v1/panel/reservas/entregar')).send({ codigo });
    expect(repetida.statusCode).toBe(409);

    const otraBotica = await con(tokenSaludTotal)(request(app).post('/api/v1/panel/reservas/entregar')).send({ codigo });
    expect(otraBotica.statusCode).toBe(404);

    const inexistente = await elna(request(app).post('/api/v1/panel/reservas/entregar')).send({ codigo: 'ZZZZZZ' });
    expect(inexistente.statusCode).toBe(404);
  });
});
