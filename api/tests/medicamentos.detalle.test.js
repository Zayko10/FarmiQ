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

const detalleDe = async (nombre) => request(app).get(`/api/v1/medicamentos/${await idDe(nombre)}`);

describe('GET /api/v1/medicamentos/:id (HU15 ficha técnica)', () => {
  it('Escenario 1: muestra la ficha completa con el aviso de consulta médica', async () => {
    const res = await detalleDe('Panadol Forte');

    expect(res.statusCode).toBe(200);
    const { ficha, medicamento } = res.body;
    expect(medicamento.nombre).toBe('Panadol Forte');
    expect(medicamento.precio_desde).toBe(12.9);
    expect(ficha.disponible).toBe(true);
    expect(ficha.principio_activo).toBe('Paracetamol');
    expect(ficha.concentracion).toBe('500 mg');
    expect(ficha.presentacion).toBe('Tabletas x 20');
    expect(ficha.dosis_referencial).toMatch(/1 tableta/);
    expect(ficha.aviso).toBe('Consulte a su médico o químico farmacéutico');
  });

  it('Escenario 1: incluye el enlace al prospecto cuando la botica lo cargó', async () => {
    const id = await idDe('Panadol Forte');
    const url = 'https://ejemplo.pe/prospecto-panadol.pdf';
    await pool.query('UPDATE medicamentos SET prospecto_url = $1 WHERE id = $2', [url, id]);
    try {
      const res = await request(app).get(`/api/v1/medicamentos/${id}`);
      expect(res.body.ficha.prospecto_url).toBe(url);
    } finally {
      await pool.query('UPDATE medicamentos SET prospecto_url = NULL WHERE id = $1', [id]);
    }
  });

  it('Escenario 2: sin ficha cargada responde "Ficha técnica no disponible" sin bloquear el resto', async () => {
    const res = await detalleDe('Omeprazol MK');

    expect(res.statusCode).toBe(200);
    expect(res.body.ficha.disponible).toBe(false);
    expect(res.body.ficha.mensaje).toBe('Ficha técnica no disponible');
    // El resto de la pantalla sigue funcionando: nombre, precio y disponibilidad
    expect(res.body.medicamento.nombre).toBe('Omeprazol MK');
    expect(res.body.medicamento.precio_desde).toBe(8);
    expect(res.body.medicamento.disponible).toBe(true);
  });

  it('responde 404 si el medicamento no existe', async () => {
    const res = await request(app).get('/api/v1/medicamentos/999999');
    expect(res.statusCode).toBe(404);
  });

  it('responde 400 si el identificador no es numérico', async () => {
    const res = await request(app).get('/api/v1/medicamentos/abc');
    expect(res.statusCode).toBe(400);
  });

  it('no requiere sesión iniciada', async () => {
    const res = await detalleDe('Advil');
    expect(res.statusCode).toBe(200);
  });
});
