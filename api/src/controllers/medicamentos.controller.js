const pool = require('../db');
const { busquedaSchema } = require('../validators/medicamentos.validator');

const LIMITE_RESULTADOS = 50;

// Escapa los comodines de LIKE para que "%" o "_" se busquen como texto normal
function escaparLike(texto) {
  return texto.replace(/[\\%_]/g, (c) => '\\' + c);
}

async function buscarMedicamentos(req, res) {
  const resultado = busquedaSchema.safeParse(req.query);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((p) => ({
      campo: p.path.join('.'),
      mensaje: p.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { q } = resultado.data;
  const patron = '%' + escaparLike(q) + '%';
  const inicio = escaparLike(q) + '%';

  try {
    const { rows } = await pool.query(
      `SELECT m.id,
              m.nombre,
              m.principio_activo,
              m.concentracion,
              m.presentacion,
              m.es_generico,
              m.requiere_receta,
              MIN(i.precio)::float8   AS precio_desde,
              COALESCE(bool_or(i.stock > 0), false) AS disponible
         FROM medicamentos m
         JOIN inventario i ON i.medicamento_id = m.id
         JOIN boticas b    ON b.id = i.botica_id AND b.activa
        WHERE m.activo
          AND (unaccent(m.nombre) ILIKE unaccent($1)
               OR unaccent(m.principio_activo) ILIKE unaccent($1))
        GROUP BY m.id
        ORDER BY (unaccent(m.nombre) ILIKE unaccent($2)) DESC, m.nombre
        LIMIT $3`,
      [patron, inicio, LIMITE_RESULTADOS]
    );

    if (rows.length === 0) {
      return res.status(200).json({
        resultados: [],
        mensaje: 'No se encontraron resultados',
        sugerencia: 'Revisa la ortografía o busca por el principio activo',
      });
    }

    return res.status(200).json({ resultados: rows });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { buscarMedicamentos };
