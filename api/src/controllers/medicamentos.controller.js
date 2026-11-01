const pool = require('../db');
const { busquedaSchema } = require('../validators/medicamentos.validator');

const LIMITE_RESULTADOS = 50;

// Escapa los comodines de LIKE para que "%" o "_" se busquen como texto normal
function escaparLike(texto) {
  return texto.replace(/[\\%_]/g, (c) => '\\' + c);
}

// Distancia en km entre el cliente (lat, lng) y una botica (fórmula de Haversine)
const distanciaSql = (pLat, pLng) => `
  (6371 * 2 * asin(sqrt(
      power(sin(radians(b.latitud - ${pLat}) / 2), 2) +
      cos(radians(${pLat})) * cos(radians(b.latitud)) *
      power(sin(radians(b.longitud - ${pLng}) / 2), 2)
  )))`;

async function buscarMedicamentos(req, res) {
  const resultado = busquedaSchema.safeParse(req.query);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((p) => ({
      campo: p.path.join('.'),
      mensaje: p.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { q, orden, solo_stock, distancia_max_km, lat, lng } = resultado.data;
  const conUbicacion = lat !== undefined && lng !== undefined;
  const soloStock = solo_stock === 'true';

  // Cada valor se agrega a params y devuelve su marcador ($1, $2, ...)
  const params = [];
  const marcador = (valor) => {
    params.push(valor);
    return '$' + params.length;
  };

  const pContiene = marcador('%' + escaparLike(q) + '%');
  const pLimite = marcador(LIMITE_RESULTADOS);

  // Condiciones sobre las filas de inventario (boticas) que cuentan para el resultado
  const condiciones = [
    'm.activo',
    'b.activa',
    `(unaccent(m.nombre) ILIKE unaccent(${pContiene}) OR unaccent(m.principio_activo) ILIKE unaccent(${pContiene}))`,
  ];

  let distanciaCol = 'NULL::float8';
  if (conUbicacion) {
    const pLat = marcador(lat);
    const pLng = marcador(lng);
    distanciaCol = distanciaSql(`${pLat}::float8`, `${pLng}::float8`);
  }
  if (soloStock) {
    condiciones.push('i.stock > 0');
  }
  if (distancia_max_km !== undefined) {
    condiciones.push(`${distanciaCol} <= ${marcador(distancia_max_km)}::float8`);
  }

  const ordenes = {
    relevancia: () => `(unaccent(m.nombre) ILIKE unaccent(${marcador(escaparLike(q) + '%')})) DESC, m.nombre`,
    precio_asc: () => 'precio_desde ASC, m.nombre',
    precio_desc: () => 'precio_desde DESC, m.nombre',
    distancia: () => 'distancia_km ASC, m.nombre',
    disponibilidad: () => 'disponible DESC, precio_desde ASC, m.nombre',
  };
  const ordenSql = ordenes[orden]();

  const filtrosActivos = (soloStock ? 1 : 0) + (distancia_max_km !== undefined ? 1 : 0);

  try {
    const { rows } = await pool.query(
      `SELECT m.id,
              m.nombre,
              m.principio_activo,
              m.concentracion,
              m.presentacion,
              m.es_generico,
              m.requiere_receta,
              MIN(i.precio)::float8                 AS precio_desde,
              COALESCE(bool_or(i.stock > 0), false) AS disponible,
              ROUND(MIN(${distanciaCol})::numeric, 2)::float8 AS distancia_km
         FROM medicamentos m
         JOIN inventario i ON i.medicamento_id = m.id
         JOIN boticas b    ON b.id = i.botica_id
        WHERE ${condiciones.join(' AND ')}
        GROUP BY m.id
        ORDER BY ${ordenSql}
        LIMIT ${pLimite}`,
      params
    );

    if (rows.length === 0) {
      return res.status(200).json({
        resultados: [],
        filtros_activos: filtrosActivos,
        mensaje: 'No se encontraron resultados',
        sugerencia:
          filtrosActivos > 0
            ? 'Prueba quitando algún filtro o buscando por el principio activo'
            : 'Revisa la ortografía o busca por el principio activo',
      });
    }

    return res.status(200).json({ resultados: rows, filtros_activos: filtrosActivos });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { buscarMedicamentos };
