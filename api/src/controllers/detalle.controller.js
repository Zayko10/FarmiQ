const pool = require('../db');
const { idSchema } = require('../validators/medicamentos.validator');

const AVISO = 'Consulte a su médico o químico farmacéutico';

async function obtenerDetalle(req, res) {
  const resultado = idSchema.safeParse(req.params);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((p) => ({
      campo: p.path.join('.'),
      mensaje: p.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  try {
    const { rows } = await pool.query(
      `SELECT m.id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
              m.categoria, m.es_generico, m.requiere_receta,
              m.dosis_referencial, m.prospecto_url,
              MIN(i.precio)::float8                 AS precio_desde,
              COALESCE(bool_or(i.stock > 0), false) AS disponible
         FROM medicamentos m
         LEFT JOIN inventario i ON i.medicamento_id = m.id
         LEFT JOIN boticas b    ON b.id = i.botica_id AND b.activa
        WHERE m.id = $1 AND m.activo
        GROUP BY m.id`,
      [resultado.data.id]
    );

    const m = rows[0];
    if (!m) {
      return res.status(404).json({ error: 'Medicamento no encontrado' });
    }

    // La ficha técnica se considera disponible si la botica cargó la dosis referencial
    const fichaDisponible = m.dosis_referencial !== null;

    const ficha = fichaDisponible
      ? {
          disponible: true,
          principio_activo: m.principio_activo,
          concentracion: m.concentracion,
          presentacion: m.presentacion,
          dosis_referencial: m.dosis_referencial,
          prospecto_url: m.prospecto_url,
          aviso: AVISO,
        }
      : { disponible: false, mensaje: 'Ficha técnica no disponible' };

    // null = invitado (sin sesión); true/false = estado del corazón para el cliente
    let esFavorito = null;
    if (req.usuario) {
      const fav = await pool.query(
        'SELECT 1 FROM favoritos WHERE usuario_id = $1 AND medicamento_id = $2',
        [req.usuario.id, m.id]
      );
      esFavorito = fav.rowCount > 0;
    }

    return res.status(200).json({
      es_favorito: esFavorito,
      medicamento: {
        id: m.id,
        nombre: m.nombre,
        principio_activo: m.principio_activo,
        concentracion: m.concentracion,
        presentacion: m.presentacion,
        categoria: m.categoria,
        es_generico: m.es_generico,
        requiere_receta: m.requiere_receta,
        precio_desde: m.precio_desde,
        disponible: m.disponible,
      },
      ficha,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { obtenerDetalle };
