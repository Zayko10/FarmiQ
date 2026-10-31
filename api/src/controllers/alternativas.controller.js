const pool = require('../db');
const { idSchema } = require('../validators/medicamentos.validator');

// Precio "desde" y disponibilidad de cada medicamento, sumando las boticas activas
const PRECIOS = `
  SELECT i.medicamento_id,
         MIN(i.precio)::float8 AS precio_desde,
         bool_or(i.stock > 0)  AS disponible
    FROM inventario i
    JOIN boticas b ON b.id = i.botica_id AND b.activa
   GROUP BY i.medicamento_id`;

const redondear = (n) => Math.round(n * 100) / 100;

async function obtenerAlternativas(req, res) {
  const resultado = idSchema.safeParse(req.params);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((p) => ({
      campo: p.path.join('.'),
      mensaje: p.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { id } = resultado.data;

  try {
    const original = await pool.query(
      `SELECT m.id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
              m.es_generico, p.precio_desde, COALESCE(p.disponible, false) AS disponible
         FROM medicamentos m
         LEFT JOIN (${PRECIOS}) p ON p.medicamento_id = m.id
        WHERE m.id = $1 AND m.activo`,
      [id]
    );

    if (!original.rows[0]) {
      return res.status(404).json({ error: 'Medicamento no encontrado' });
    }

    const medicamento = original.rows[0];

    // Alternativa = genérico con el mismo principio activo, concentración y presentación
    const { rows } = await pool.query(
      `SELECT m.id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
              m.es_generico, p.precio_desde, COALESCE(p.disponible, false) AS disponible
         FROM medicamentos m
         JOIN (${PRECIOS}) p ON p.medicamento_id = m.id
        WHERE m.activo
          AND m.es_generico
          AND m.id <> $1
          AND lower(m.principio_activo) = lower($2)
          AND lower(m.concentracion)    = lower($3)
          AND lower(m.presentacion)     = lower($4)
        ORDER BY COALESCE(p.disponible, false) DESC, p.precio_desde ASC, m.nombre`,
      [medicamento.id, medicamento.principio_activo, medicamento.concentracion, medicamento.presentacion]
    );

    if (rows.length === 0) {
      return res.status(200).json({
        medicamento,
        alternativas: [],
        mensaje: 'No hay alternativas genéricas disponibles para este medicamento',
      });
    }

    const alternativas = rows.map((alt) => {
      if (medicamento.precio_desde === null || medicamento.precio_desde === undefined) {
        return { ...alt, ahorro_soles: null, ahorro_porcentaje: null };
      }
      const ahorro = medicamento.precio_desde - alt.precio_desde;
      return {
        ...alt,
        ahorro_soles: redondear(ahorro),
        ahorro_porcentaje: Math.round((ahorro / medicamento.precio_desde) * 1000) / 10,
      };
    });

    return res.status(200).json({ medicamento, alternativas });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { obtenerAlternativas };
