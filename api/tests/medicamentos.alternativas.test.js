const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

async function idDe(nombre) {
  const { rows } = await pool.query('SELECT id FROM medicamentos WHERE nombre = $1', [nombre]);
  return rows[0].id;
}

afterAll(async () => {
  await pool.end();
});

const alternativasDe = async (nombre) => request(app).get(`/api/v1/medicamentos/${await idDe(nombre)}/alternativas`);

describe('GET /api/v1/medicamentos/:id/alternativas (HU05)', () => {
  it('Escenario 1: lista los genéricos equivalentes con ahorro en soles y porcentaje', async () => {
    const res = await alternativasDe('Panadol Forte');

    expect(res.statusCode).toBe(200);
    expect(res.body.medicamento.nombre).toBe('Panadol Forte');
    expect(res.body.medicamento.precio_desde).toBe(12.9);

    const genfar = res.body.alternativas.find((a) => a.nombre === 'Paracetamol Genfar');
    expect(genfar.es_generico).toBe(true);
    expect(genfar.precio_desde).toBe(7.9);
    expect(genfar.ahorro_soles).toBe(5);
    expect(genfar.ahorro_porcentaje).toBe(38.8);
  });

  it('ordena primero las alternativas con stock y luego por precio', async () => {
    const res = await alternativasDe('Panadol Forte');

    const nombres = res.body.alternativas.map((a) => a.nombre);
    // Paracetamol MK es más barato (6.50) pero no tiene stock: va después de Genfar
    expect(nombres).toEqual(['Paracetamol Genfar', 'Paracetamol MK']);
    expect(res.body.alternativas[1].disponible).toBe(false);
  });

  it('calcula el ahorro de otra marca (Advil vs Ibuprofeno MK)', async () => {
    const res = await alternativasDe('Advil');

    expect(res.statusCode).toBe(200);
    expect(res.body.alternativas).toHaveLength(1);
    expect(res.body.alternativas[0].nombre).toBe('Ibuprofeno MK');
    expect(res.body.alternativas[0].ahorro_soles).toBe(9.5);
    expect(res.body.alternativas[0].ahorro_porcentaje).toBe(65.5);
  });

  it('no mezcla medicamentos con distinta concentración o presentación', async () => {
    const res = await alternativasDe('Panadol Forte');

    res.body.alternativas.forEach((a) => {
      expect(a.principio_activo).toBe('Paracetamol');
      expect(a.concentracion).toBe('500 mg');
      expect(a.presentacion).toBe('Tabletas x 20');
    });
  });

  it('Escenario 2: sin genérico equivalente devuelve lista vacía y mantiene el original', async () => {
    const res = await alternativasDe('Strepsils');

    expect(res.statusCode).toBe(200);
    expect(res.body.medicamento.nombre).toBe('Strepsils');
    expect(res.body.alternativas).toEqual([]);
    expect(res.body.mensaje).toBe('No hay alternativas genéricas disponibles para este medicamento');
  });

  it('si el medicamento consultado ya es genérico, no se ofrece a sí mismo', async () => {
    const res = await alternativasDe('Paracetamol Genfar');

    expect(res.statusCode).toBe(200);
    const nombres = res.body.alternativas.map((a) => a.nombre);
    expect(nombres).not.toContain('Paracetamol Genfar');
    expect(nombres).toContain('Paracetamol MK');
  });

  it('responde 404 si el medicamento no existe', async () => {
    const res = await request(app).get('/api/v1/medicamentos/999999/alternativas');
    expect(res.statusCode).toBe(404);
  });

  it('responde 400 si el identificador no es numérico', async () => {
    const res = await request(app).get('/api/v1/medicamentos/abc/alternativas');
    expect(res.statusCode).toBe(400);
  });

  it('no requiere sesión iniciada (el invitado puede comparar)', async () => {
    const res = await alternativasDe('Panadol Forte');
    expect(res.statusCode).toBe(200);
  });
});
