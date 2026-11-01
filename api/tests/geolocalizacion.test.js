const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

// Botica Elna está en Chorrillos. CERCA = cliente a unos 200 m; LEJOS = cliente en Miraflores (~9 km)
const CERCA = { lat: -12.199, lng: -76.976 };
const LEJOS = { lat: -12.1219, lng: -77.0297 };

async function idDe(nombre) {
  const { rows } = await pool.query('SELECT id FROM medicamentos WHERE nombre = $1', [nombre]);
  return rows[0].id;
}

const disponibilidadDe = async (nombre, query = {}) =>
  request(app).get(`/api/v1/medicamentos/${await idDe(nombre)}/disponibilidad`).query(query);

// Boticas temporales para probar el orden entre varias sedes.
// Usan Claritin, que ninguna otra suite consulta, y se borran al terminar.
async function limpiarTemporales() {
  await pool.query("DELETE FROM boticas WHERE nombre LIKE 'TEST %'");
}

beforeAll(async () => {
  await limpiarTemporales();
  const claritin = await idDe('Claritin');
  const nueva = async (nombre, lat, lng, activa, stock, precio) => {
    const { rows } = await pool.query(
      `INSERT INTO boticas (nombre, direccion, latitud, longitud, activa)
       VALUES ($1, 'Dirección de prueba', $2, $3, $4) RETURNING id`,
      [nombre, lat, lng, activa]
    );
    await pool.query(
      'INSERT INTO inventario (botica_id, medicamento_id, stock, precio) VALUES ($1, $2, $3, $4)',
      [rows[0].id, claritin, stock, precio]
    );
  };
  // Se insertan en desorden a propósito: la API debe ordenarlas por distancia
  await nueva('TEST Botica B (5 km)', -12.1525, -76.9746, true, 3, 16.0);
  await nueva('TEST Botica A (2 km)', -12.1795, -76.9746, true, 5, 17.5);
  await nueva('TEST Botica sin stock', -12.2, -76.97, true, 0, 15.0);
  await nueva('TEST Botica inactiva', -12.2, -76.97, false, 9, 15.0);
});

afterAll(async () => {
  await limpiarTemporales();
  await pool.end();
});

describe('GET /api/v1/medicamentos/:id/disponibilidad (HU04)', () => {
  it('Escenario 1: lista las boticas con stock, con distancia, coordenadas y hora de actualización', async () => {
    const res = await disponibilidadDe('Panadol Forte', CERCA);

    expect(res.statusCode).toBe(200);
    expect(res.body.ubicacion_activa).toBe(true);
    expect(res.body.aviso_ubicacion).toBeNull();
    expect(res.body.boticas).toHaveLength(1);

    const elna = res.body.boticas[0];
    expect(elna.nombre).toBe('Botica Elna');
    expect(elna.stock).toBe(25);
    expect(elna.precio).toBe(12.9);
    expect(elna.distancia_km).toBeLessThan(1);
    expect(typeof elna.latitud).toBe('number');
    expect(typeof elna.longitud).toBe('number');
    expect(elna.minutos_desde_actualizacion).toBeGreaterThanOrEqual(0);
  });

  it('ordena las boticas de la más cercana a la más lejana', async () => {
    const res = await disponibilidadDe('Claritin', CERCA);

    const nombres = res.body.boticas.map((b) => b.nombre);
    expect(nombres).toEqual(['Botica Elna', 'TEST Botica A (2 km)', 'TEST Botica B (5 km)']);
    const distancias = res.body.boticas.map((b) => b.distancia_km);
    expect(distancias).toEqual([...distancias].sort((a, b) => a - b));
  });

  it('no muestra boticas sin stock ni boticas inactivas', async () => {
    const res = await disponibilidadDe('Claritin', CERCA);

    const nombres = res.body.boticas.map((b) => b.nombre);
    expect(nombres).not.toContain('TEST Botica sin stock');
    expect(nombres).not.toContain('TEST Botica inactiva');
  });

  it('Escenario 2: sin ubicación explica por qué se necesita y lista las boticas sin distancia', async () => {
    const res = await disponibilidadDe('Panadol Forte');

    expect(res.statusCode).toBe(200);
    expect(res.body.ubicacion_activa).toBe(false);
    expect(res.body.aviso_ubicacion.accion).toBe('activar_ubicacion');
    expect(res.body.aviso_ubicacion.mensaje).toMatch(/ubicación/);
    expect(res.body.boticas).toHaveLength(1);
    expect(res.body.boticas[0].distancia_km).toBeNull();
  });

  it('Escenario 3: sin stock en ninguna botica sugiere el Filtro de Ahorro', async () => {
    const res = await disponibilidadDe('Paracetamol MK', CERCA);

    expect(res.statusCode).toBe(200);
    expect(res.body.boticas).toEqual([]);
    expect(res.body.mensaje).toBe('No hay stock disponible en las boticas afiliadas');
    expect(res.body.sugerencia).toMatch(/Filtro de Ahorro/);
  });

  it('calcula una distancia mayor para un cliente lejano', async () => {
    const res = await disponibilidadDe('Panadol Forte', LEJOS);

    expect(res.body.boticas[0].distancia_km).toBeGreaterThan(5);
  });

  it('responde 404 si el medicamento no existe', async () => {
    const res = await request(app).get('/api/v1/medicamentos/999999/disponibilidad');
    expect(res.statusCode).toBe(404);
  });

  it('responde 400 si se envía solo la latitud', async () => {
    const res = await disponibilidadDe('Panadol Forte', { lat: -12.2 });

    expect(res.statusCode).toBe(400);
    expect(res.body.detalles[0].mensaje).toMatch(/lat y lng juntas/);
  });

  it('responde 400 con coordenadas fuera de rango', async () => {
    const res = await disponibilidadDe('Panadol Forte', { lat: 200, lng: 0 });
    expect(res.statusCode).toBe(400);
  });

  it('no requiere sesión iniciada', async () => {
    const res = await disponibilidadDe('Advil', CERCA);
    expect(res.statusCode).toBe(200);
  });
});

describe('GET /api/v1/boticas (pantalla Sedes)', () => {
  it('lista las sedes activas ordenadas por cercanía', async () => {
    const res = await request(app).get('/api/v1/boticas').query(CERCA);

    expect(res.statusCode).toBe(200);
    expect(res.body.ubicacion_activa).toBe(true);
    const nombres = res.body.boticas.map((b) => b.nombre);
    expect(nombres[0]).toBe('Botica Elna');
    expect(nombres).not.toContain('TEST Botica inactiva');
    expect(res.body.boticas[0].distancia_km).toBeLessThan(1);
  });

  it('sin ubicación lista las sedes sin distancia y con el aviso', async () => {
    const res = await request(app).get('/api/v1/boticas');

    expect(res.statusCode).toBe(200);
    expect(res.body.ubicacion_activa).toBe(false);
    expect(res.body.aviso_ubicacion.accion).toBe('activar_ubicacion');
    res.body.boticas.forEach((b) => expect(b.distancia_km).toBeNull());
  });

  it('responde 400 si falta una de las coordenadas', async () => {
    const res = await request(app).get('/api/v1/boticas').query({ lng: -76.97 });
    expect(res.statusCode).toBe(400);
  });
});
