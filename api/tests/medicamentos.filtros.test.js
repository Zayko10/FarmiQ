const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

afterAll(async () => {
  await pool.end();
});

// Cliente a pocos metros de Botica Elna (Chorrillos) y cliente lejos (Miraflores, ~9 km)
const CERCA = { lat: -12.199, lng: -76.976 };
const LEJOS = { lat: -12.1219, lng: -77.0297 };

const buscar = (params) => request(app).get('/api/v1/medicamentos').query({ q: 'paracetamol', ...params });
const nombres = (res) => res.body.resultados.map((m) => m.nombre);

describe('GET /api/v1/medicamentos con orden y filtros (HU16)', () => {
  it('Escenario 1: ordena de menor a mayor precio', async () => {
    const res = await buscar({ orden: 'precio_asc' });

    expect(res.statusCode).toBe(200);
    expect(nombres(res)).toEqual(['Paracetamol MK', 'Paracetamol Genfar', 'Panadol Forte']);
  });

  it('ordena de mayor a menor precio', async () => {
    const res = await buscar({ orden: 'precio_desc' });
    expect(nombres(res)).toEqual(['Panadol Forte', 'Paracetamol Genfar', 'Paracetamol MK']);
  });

  it('ordena por disponibilidad: primero los que tienen stock', async () => {
    const res = await buscar({ orden: 'disponibilidad' });

    expect(nombres(res)).toEqual(['Paracetamol Genfar', 'Panadol Forte', 'Paracetamol MK']);
    expect(res.body.resultados[2].disponible).toBe(false);
  });

  it('"Solo con stock" oculta lo que no tiene stock e indica 1 filtro activo', async () => {
    const res = await buscar({ solo_stock: 'true' });

    expect(nombres(res)).not.toContain('Paracetamol MK');
    expect(nombres(res)).toContain('Panadol Forte');
    expect(res.body.filtros_activos).toBe(1);
  });

  it('Escenario 2: filtros combinados (solo con stock + máximo 3 km) indican 2 filtros activos', async () => {
    const res = await buscar({ solo_stock: 'true', distancia_max_km: 3, ...CERCA });

    expect(res.statusCode).toBe(200);
    expect(nombres(res)).toEqual(expect.arrayContaining(['Panadol Forte', 'Paracetamol Genfar']));
    expect(nombres(res)).not.toContain('Paracetamol MK');
    expect(res.body.filtros_activos).toBe(2);
    res.body.resultados.forEach((m) => {
      expect(m.distancia_km).toBeLessThanOrEqual(3);
    });
  });

  it('con la botica fuera del radio no hay resultados y se sugiere quitar filtros', async () => {
    const res = await buscar({ distancia_max_km: 3, ...LEJOS });

    expect(res.statusCode).toBe(200);
    expect(res.body.resultados).toEqual([]);
    expect(res.body.filtros_activos).toBe(1);
    expect(res.body.sugerencia).toMatch(/quitando algún filtro/);
  });

  it('muestra la distancia en km cuando se envía la ubicación', async () => {
    const res = await buscar({ ...LEJOS });

    expect(res.body.resultados[0].distancia_km).toBeGreaterThan(5);
    expect(res.body.resultados[0].distancia_km).toBeLessThan(15);
  });

  it('Escenario 3: sin filtros devuelve la lista completa y 0 filtros activos', async () => {
    const res = await buscar({});

    expect(nombres(res)).toHaveLength(3);
    expect(res.body.filtros_activos).toBe(0);
  });

  it('pide la ubicación si se ordena o filtra por distancia sin enviarla', async () => {
    const a = await buscar({ orden: 'distancia' });
    const b = await buscar({ distancia_max_km: 3 });

    expect(a.statusCode).toBe(400);
    expect(b.statusCode).toBe(400);
    expect(a.body.detalles[0].mensaje).toMatch(/ubicación/);
  });

  it('rechaza un orden desconocido', async () => {
    const res = await buscar({ orden: 'inventado' });
    expect(res.statusCode).toBe(400);
  });
});
