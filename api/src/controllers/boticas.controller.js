const pool = require('../db');
const {
  sedesSchema,
  ubicacionSchema,
  idSchema,
  productosBoticaSchema,
} = require('../validators/medicamentos.validator');
const { distanciaSql, AVISO_UBICACION, detallesDeError } = require('./ubicacion.util');

const escaparLike = (texto) => texto.replace(/[\\%_]/g, (c) => '\\' + c);

// Sedes afiliadas con su distancia al cliente. Con radio_km solo trae las que están dentro de ese radio.
async function listarBoticas(req, res) {
  const consulta = sedesSchema.safeParse(req.query);

  if (!consulta.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(consulta.error) });
  }

  const { lat, lng, radio_km } = consulta.data;
  const conUbicacion = lat !== undefined && lng !== undefined;

  const params = [];
  let distanciaCol = 'NULL::float8';
  if (conUbicacion) {
    params.push(lat, lng);
    distanciaCol = distanciaSql('$1::float8', '$2::float8');
  }

  let filtroRadio = '';
  if (radio_km !== undefined) {
    params.push(radio_km);
    filtroRadio = `AND ${distanciaCol} <= $${params.length}::float8`;
  }

  try {
    const { rows } = await pool.query(
      `SELECT b.id,
              b.nombre,
              b.direccion,
              b.telefono,
              b.latitud::float8  AS latitud,
              b.longitud::float8 AS longitud,
              (SELECT count(*)::int FROM inventario i
                WHERE i.botica_id = b.id AND (i.stock - i.stock_reservado) > 0) AS productos_con_stock,
              ROUND((${distanciaCol})::numeric, 2)::float8 AS distancia_km
         FROM boticas b
        WHERE b.activa ${filtroRadio}
        ORDER BY distancia_km ASC NULLS LAST, b.nombre`,
      params
    );

    const base = {
      ubicacion_activa: conUbicacion,
      aviso_ubicacion: conUbicacion ? null : AVISO_UBICACION,
      radio_km: radio_km ?? null,
      boticas: rows,
    };

    if (rows.length === 0 && radio_km !== undefined) {
      return res.status(200).json({
        ...base,
        mensaje: `No hay boticas afiliadas a menos de ${radio_km} km de ti`,
        sugerencia: 'Amplía el radio de búsqueda para ver más boticas',
      });
    }
    return res.status(200).json(base);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

// Datos de una botica (con distancia si el cliente envía su ubicación)
async function obtenerBotica(req, res) {
  const id = idSchema.safeParse({ id: req.params.id });
  const ubicacion = ubicacionSchema.safeParse(req.query);
  if (!id.success || !ubicacion.success) {
    const detalles = [
      ...(id.success ? [] : [{ campo: 'id', mensaje: 'El identificador de la botica no es válido' }]),
      ...(ubicacion.success ? [] : detallesDeError(ubicacion.error)),
    ];
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { lat, lng } = ubicacion.data;
  const conUbicacion = lat !== undefined && lng !== undefined;
  const params = [id.data.id];
  let distanciaCol = 'NULL::float8';
  if (conUbicacion) {
    params.push(lat, lng);
    distanciaCol = distanciaSql('$2::float8', '$3::float8');
  }

  try {
    const { rows } = await pool.query(
      `SELECT b.id, b.nombre, b.direccion, b.telefono,
              b.latitud::float8 AS latitud, b.longitud::float8 AS longitud,
              (SELECT count(*)::int FROM inventario i
                WHERE i.botica_id = b.id AND (i.stock - i.stock_reservado) > 0) AS productos_con_stock,
              ROUND((${distanciaCol})::numeric, 2)::float8 AS distancia_km
         FROM boticas b
        WHERE b.id = $1 AND b.activa`,
      params
    );
    if (!rows[0]) return res.status(404).json({ error: 'Botica no encontrada' });
    return res.status(200).json({ botica: rows[0] });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

// Productos que vende una botica, con el stock disponible (ya descontadas las reservas pendientes)
async function productosDeBotica(req, res) {
  const id = idSchema.safeParse({ id: req.params.id });
  const filtros = productosBoticaSchema.safeParse(req.query);
  if (!id.success || !filtros.success) {
    const detalles = [
      ...(id.success ? [] : [{ campo: 'id', mensaje: 'El identificador de la botica no es válido' }]),
      ...(filtros.success ? [] : detallesDeError(filtros.error)),
    ];
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const params = [id.data.id];
  const condiciones = ['i.botica_id = $1', 'm.activo'];
  if (filtros.data.q) {
    params.push('%' + escaparLike(filtros.data.q) + '%');
    condiciones.push(
      `(unaccent(m.nombre) ILIKE unaccent($${params.length}) OR unaccent(m.principio_activo) ILIKE unaccent($${params.length}))`
    );
  }
  if (filtros.data.solo_stock === 'true') condiciones.push('(i.stock - i.stock_reservado) > 0');

  try {
    const botica = await pool.query('SELECT id, nombre FROM boticas WHERE id = $1 AND activa', [id.data.id]);
    if (!botica.rows[0]) return res.status(404).json({ error: 'Botica no encontrada' });

    const { rows } = await pool.query(
      `SELECT m.id, m.nombre, m.principio_activo, m.concentracion, m.presentacion, m.categoria,
              m.es_generico, m.requiere_receta,
              (i.stock - i.stock_reservado) AS stock,
              i.precio::float8 AS precio,
              i.actualizado_en,
              FLOOR(EXTRACT(EPOCH FROM (now() - i.actualizado_en)) / 60)::int AS minutos_desde_actualizacion
         FROM inventario i
         JOIN medicamentos m ON m.id = i.medicamento_id
        WHERE ${condiciones.join(' AND ')}
        ORDER BY ((i.stock - i.stock_reservado) > 0) DESC, m.categoria, m.nombre
        LIMIT 200`,
      params
    );
    return res.status(200).json({ botica: botica.rows[0], productos: rows });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { listarBoticas, obtenerBotica, productosDeBotica };
