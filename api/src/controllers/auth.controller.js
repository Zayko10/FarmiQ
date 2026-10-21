const bcrypt = require('bcryptjs');
const pool = require('../db');
const { registroSchema } = require('../validators/auth.validator');

async function registrar(req, res) {
  const resultado = registroSchema.safeParse(req.body);

  if (!resultado.success) {
    const detalles = resultado.error.issues.map((problema) => ({
      campo: problema.path.join('.'),
      mensaje: problema.message,
    }));
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const { nombre, email, telefono, password } = resultado.data;

  try {
    const hash = await bcrypt.hash(password, 10);

    const { rows } = await pool.query(
      'INSERT INTO usuarios (nombre, email, telefono, password_hash, acepto_terminos_en) ' +
        'VALUES ($1, $2, $3, $4, now()) ' +
        'RETURNING id, nombre, email, telefono, rol, creado_en',
      [nombre, email, telefono || null, hash]
    );

    return res.status(201).json({ usuario: rows[0] });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Este correo ya está registrado' });
    }
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { registrar };
