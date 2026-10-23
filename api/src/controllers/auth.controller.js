const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { registroSchema, loginSchema } = require('../validators/auth.validator');

function formatearErrores(error) {
  return error.issues.map((problema) => ({
    campo: problema.path.join('.'),
    mensaje: problema.message,
  }));
}

async function registrar(req, res) {
  const resultado = registroSchema.safeParse(req.body);

  if (!resultado.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: formatearErrores(resultado.error) });
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

// Hash falso para gastar el mismo tiempo cuando el correo no existe
const HASH_FALSO = '$2a$10$7EqJtq98hPqEX7fNZaFWoOa5kYq1m8Jj3uXk0cJ9r1Xr5eJrZ0m2e';

async function login(req, res) {
  const resultado = loginSchema.safeParse(req.body);

  if (!resultado.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: formatearErrores(resultado.error) });
  }

  const { email, password } = resultado.data;

  try {
    const { rows } = await pool.query(
      'SELECT id, nombre, email, telefono, rol, botica_id, password_hash FROM usuarios WHERE email = $1',
      [email]
    );

    const usuario = rows[0];
    const coincide = await bcrypt.compare(password, usuario ? usuario.password_hash : HASH_FALSO);

    if (!usuario || !coincide) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }

    const token = jwt.sign(
      { sub: String(usuario.id), rol: usuario.rol },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    delete usuario.password_hash;
    return res.status(200).json({ token, usuario });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

module.exports = { registrar, login };
