const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

afterAll(async () => {
  await pool.end();
});

const buscar = (q) => request(app).get('/api/v1/medicamentos').query(q === undefined ? {} : { q });

describe('GET /api/v1/medicamentos?q= (HU03)', () => {
  it('Escenario 1: encuentra por nombre comercial e indica presentación y precio "desde"', async () => {
    const res = await buscar('Panadol');

    expect(res.statusCode).toBe(200);
    const panadol = res.body.resultados.find((m) => m.nombre === 'Panadol Forte');
    expect(panadol).toBeDefined();
    expect(panadol.presentacion).toBe('Tabletas x 20');
    expect(panadol.precio_desde).toBe(12.9);
    expect(panadol.disponible).toBe(true);
  });

  it('Escenario 1: encuentra por principio activo (marca y genéricos)', async () => {
    const res = await buscar('paracetamol');

    expect(res.statusCode).toBe(200);
    const nombres = res.body.resultados.map((m) => m.nombre);
    expect(nombres).toEqual(expect.arrayContaining(['Panadol Forte', 'Paracetamol Genfar']));
  });

  it('ignora mayúsculas y tildes ("losartan" encuentra "Losartán")', async () => {
    const res = await buscar('LOSARTAN');

    expect(res.statusCode).toBe(200);
    expect(res.body.resultados.map((m) => m.nombre)).toContain('Losartán MK');
  });

  it('marca como no disponible un medicamento sin stock', async () => {
    const res = await buscar('Paracetamol MK');

    const mk = res.body.resultados.find((m) => m.nombre === 'Paracetamol MK');
    expect(mk.disponible).toBe(false);
  });

  it('Escenario 2: sin coincidencias devuelve lista vacía con mensaje y sugerencia', async () => {
    const res = await buscar('zzzxxx');

    expect(res.statusCode).toBe(200);
    expect(res.body.resultados).toEqual([]);
    expect(res.body.mensaje).toBe('No se encontraron resultados');
    expect(res.body.sugerencia).toMatch(/principio activo/);
  });

  it('trata "%" como texto y no como comodín', async () => {
    const res = await buscar('%%');

    expect(res.statusCode).toBe(200);
    expect(res.body.resultados).toEqual([]);
  });

  it('rechaza una búsqueda demasiado corta con 400', async () => {
    const res = await buscar('a');
    expect(res.statusCode).toBe(400);
  });

  it('rechaza una búsqueda sin término con 400', async () => {
    const res = await buscar();
    expect(res.statusCode).toBe(400);
  });

  it('no requiere sesión iniciada (el invitado puede buscar)', async () => {
    const res = await buscar('Advil');
    expect(res.statusCode).toBe(200);
  });
});
