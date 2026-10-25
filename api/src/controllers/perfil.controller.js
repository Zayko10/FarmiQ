const pool = require('../db');
const { perfilSchema } = require('../validators/perfil.validator');

const COLUMNAS = 'id, nombre, email, telefono, direccion, rol, creado_en';

async function obtenerPerfil(req, res) {
  try {
    const { rows } = await pool.query(
      'SELECT ' + COLUMNAS + ' FROM usuarios WHERE id = $1',
      [req.usuario.id]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    return res.json({ usuario: rows[0] });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

async function actualizarPerfil(req, res) {
  const resultado = perfilSchema.safeParse(req.body);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((p) => ({
      campo: p.path.join('.'),
      mensaje: p.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { nombre, telefono, direccion } = resultado.data;

  try {
    const { rows } = await pool.query(
      'UPDATE usuarios SET ' +
        'nombre = COALESCE($1, nombre), ' +
        "telefono = CASE WHEN $2::text IS NULL THEN telefono WHEN $2::text = '' THEN NULL ELSE $2::text END, " +
        'direccion = COALESCE($3, direccion) ' +
        'WHERE id = $4 ' +
        'RETURNING ' + COLUMNAS,
      [nombre ?? null, telefono ?? null, direccion ?? null, req.usuario.id]
    );

    if (!rows[0]) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    return res.json({ usuario: rows[0] });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { obtenerPerfil, actualizarPerfil };
