const pool = require('../db');
const { ubicacionSchema } = require('../validators/medicamentos.validator');
const { distanciaSql, AVISO_UBICACION, detallesDeError } = require('./ubicacion.util');

// Sedes afiliadas, independientes de un medicamento (pantalla "Sedes")
async function listarBoticas(req, res) {
  const ubicacion = ubicacionSchema.safeParse(req.query);

  if (!ubicacion.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(ubicacion.error) });
  }

  const { lat, lng } = ubicacion.data;
  const conUbicacion = lat !== undefined && lng !== undefined;

  const params = [];
  let distanciaCol = 'NULL::float8';
  if (conUbicacion) {
    params.push(lat, lng);
    distanciaCol = distanciaSql('$1::float8', '$2::float8');
  }

  try {
    const { rows } = await pool.query(
      `SELECT b.id,
              b.nombre,
              b.direccion,
              b.telefono,
              b.latitud::float8  AS latitud,
              b.longitud::float8 AS longitud,
              ROUND((${distanciaCol})::numeric, 2)::float8 AS distancia_km
         FROM boticas b
        WHERE b.activa
        ORDER BY distancia_km ASC NULLS LAST, b.nombre`,
      params
    );

    return res.status(200).json({
      ubicacion_activa: conUbicacion,
      aviso_ubicacion: conUbicacion ? null : AVISO_UBICACION,
      boticas: rows,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { listarBoticas };
