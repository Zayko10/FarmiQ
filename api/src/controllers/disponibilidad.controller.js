const pool = require('../db');
const { idSchema, ubicacionSchema } = require('../validators/medicamentos.validator');
const { distanciaSql, AVISO_UBICACION, detallesDeError } = require('./ubicacion.util');

async function obtenerDisponibilidad(req, res) {
  const id = idSchema.safeParse(req.params);
  const ubicacion = ubicacionSchema.safeParse(req.query);

  if (!id.success || !ubicacion.success) {
    const detalles = [
      ...(id.success ? [] : detallesDeError(id.error)),
      ...(ubicacion.success ? [] : detallesDeError(ubicacion.error)),
    ];
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { lat, lng } = ubicacion.data;
  const conUbicacion = lat !== undefined && lng !== undefined;

  try {
    const med = await pool.query(
      'SELECT id, nombre, presentacion FROM medicamentos WHERE id = $1 AND activo',
      [id.data.id]
    );
    if (!med.rows[0]) {
      return res.status(404).json({ error: 'Medicamento no encontrado' });
    }

    const params = [id.data.id];
    let distanciaCol = 'NULL::float8';
    if (conUbicacion) {
      params.push(lat, lng);
      distanciaCol = distanciaSql('$2::float8', '$3::float8');
    }

    const { rows } = await pool.query(
      `SELECT b.id,
              b.nombre,
              b.direccion,
              b.telefono,
              b.latitud::float8  AS latitud,
              b.longitud::float8 AS longitud,
              i.stock,
              i.precio::float8   AS precio,
              i.actualizado_en,
              FLOOR(EXTRACT(EPOCH FROM (now() - i.actualizado_en)) / 60)::int AS minutos_desde_actualizacion,
              ROUND((${distanciaCol})::numeric, 2)::float8 AS distancia_km
         FROM inventario i
         JOIN boticas b ON b.id = i.botica_id AND b.activa
        WHERE i.medicamento_id = $1 AND i.stock > 0
        ORDER BY distancia_km ASC NULLS LAST, i.precio ASC, b.nombre`,
      params
    );

    const base = {
      medicamento: med.rows[0],
      ubicacion_activa: conUbicacion,
      aviso_ubicacion: conUbicacion ? null : AVISO_UBICACION,
    };

    // Escenario 3: ninguna botica afiliada tiene stock
    if (rows.length === 0) {
      return res.status(200).json({
        ...base,
        boticas: [],
        mensaje: 'No hay stock disponible en las boticas afiliadas',
        sugerencia: 'Activa el Filtro de Ahorro para ver alternativas genéricas',
      });
    }

    return res.status(200).json({ ...base, boticas: rows });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { obtenerDisponibilidad };
