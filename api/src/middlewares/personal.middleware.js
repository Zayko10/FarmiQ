const pool = require('../db');

// Solo personal de botica. Lee la botica desde la base de datos en cada petición
// (así, si se le quita el acceso a alguien, deja de funcionar aunque conserve su token).
async function cargarBotica(req, res, next) {
  try {
    const { rows } = await pool.query(
      `SELECT u.botica_id, b.nombre
         FROM usuarios u
         JOIN boticas b ON b.id = u.botica_id AND b.activa
        WHERE u.id = $1 AND u.rol = 'personal'`,
      [req.usuario.id]
    );
    if (!rows[0]) {
      return res.status(403).json({ error: 'Tu cuenta no está asociada a una botica activa' });
    }
    req.botica = { id: rows[0].botica_id, nombre: rows[0].nombre };
    return next();
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { cargarBotica };
