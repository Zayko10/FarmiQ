const pool = require('../db');
const { idSchema } = require('../validators/medicamentos.validator');
const { detallesDeError } = require('./ubicacion.util');

// Precio "desde" y disponibilidad de cada medicamento, sumando las boticas activas
const PRECIOS = `
  SELECT i.medicamento_id,
         MIN(i.precio)::float8 AS precio_desde,
         bool_or(i.stock > 0)  AS disponible
    FROM inventario i
    JOIN boticas b ON b.id = i.botica_id AND b.activa
   GROUP BY i.medicamento_id`;

// "Mis favoritos": los más recientes primero
async function listarFavoritos(req, res) {
  try {
    const { rows } = await pool.query(
      `SELECT m.id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
              m.es_generico, p.precio_desde, COALESCE(p.disponible, false) AS disponible,
              f.creado_en AS agregado_en
         FROM favoritos f
         JOIN medicamentos m ON m.id = f.medicamento_id AND m.activo
         LEFT JOIN (${PRECIOS}) p ON p.medicamento_id = m.id
        WHERE f.usuario_id = $1
        ORDER BY f.creado_en DESC, m.nombre`,
      [req.usuario.id]
    );

    if (rows.length === 0) {
      return res.status(200).json({ favoritos: [], mensaje: 'Aún no tienes medicamentos favoritos' });
    }
    return res.status(200).json({ favoritos: rows });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

// Agregar a favoritos (repetirlo no duplica nada)
async function agregarFavorito(req, res) {
  const id = idSchema.safeParse(req.params);
  if (!id.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(id.error) });
  }

  try {
    const med = await pool.query('SELECT id FROM medicamentos WHERE id = $1 AND activo', [id.data.id]);
    if (!med.rows[0]) {
      return res.status(404).json({ error: 'Medicamento no encontrado' });
    }

    const { rowCount } = await pool.query(
      `INSERT INTO favoritos (usuario_id, medicamento_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [req.usuario.id, id.data.id]
    );

    return res
      .status(rowCount === 1 ? 201 : 200)
      .json({ favorito: true, medicamento_id: med.rows[0].id });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

// Quitar de favoritos (si no estaba, no pasa nada)
async function quitarFavorito(req, res) {
  const id = idSchema.safeParse(req.params);
  if (!id.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(id.error) });
  }

  try {
    await pool.query('DELETE FROM favoritos WHERE usuario_id = $1 AND medicamento_id = $2', [
      req.usuario.id,
      id.data.id,
    ]);
    return res.status(200).json({ favorito: false, medicamento_id: id.data.id });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { listarFavoritos, agregarFavorito, quitarFavorito };
