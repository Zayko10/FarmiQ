const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { enviarCorreo } = require('../services/correo.service');
const {
  olvidePasswordSchema,
  restablecerPasswordSchema,
} = require('../validators/auth.validator');

const MENSAJE_GENERICO =
  'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña';
const MINUTOS_VIGENCIA = 60;

function hashearToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function detallesDe(error) {
  return error.issues.map((p) => ({ campo: p.path.join('.'), mensaje: p.message }));
}

async function olvidePassword(req, res) {
  const resultado = olvidePasswordSchema.safeParse(req.body);
  if (!resultado.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDe(resultado.error) });
  }

  const { email } = resultado.data;

  try {
    const { rows } = await pool.query('SELECT id, nombre FROM usuarios WHERE email = $1', [email]);
    const usuario = rows[0];

    if (usuario) {
      const token = crypto.randomBytes(32).toString('hex');

      await pool.query(
        'INSERT INTO password_resets (usuario_id, token_hash, expira_en) ' +
          "VALUES ($1, $2, now() + ($3 || ' minutes')::interval)",
        [usuario.id, hashearToken(token), String(MINUTOS_VIGENCIA)]
      );

      await enviarCorreo({
        para: email,
        asunto: 'Recupera tu contraseña de FarmiQ',
        texto:
          'Hola ' + usuario.nombre + ', usa este código para restablecer tu contraseña ' +
          '(vence en ' + MINUTOS_VIGENCIA + ' minutos):\n' + token,
      });
    }

    return res.status(200).json({ mensaje: MENSAJE_GENERICO });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

async function restablecerPassword(req, res) {
  const resultado = restablecerPasswordSchema.safeParse(req.body);
  if (!resultado.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDe(resultado.error) });
  }

  const { token, password } = resultado.data;
  const cliente = await pool.connect();

  try {
    await cliente.query('BEGIN');

    const { rows } = await cliente.query(
      'SELECT id, usuario_id FROM password_resets ' +
        'WHERE token_hash = $1 AND usado_en IS NULL AND expira_en > now() ' +
        'FOR UPDATE',
      [hashearToken(token)]
    );

    if (!rows[0]) {
      await cliente.query('ROLLBACK');
      return res.status(400).json({ error: 'El enlace es inválido o ya venció' });
    }

    const hash = await bcrypt.hash(password, 10);

    await cliente.query('UPDATE usuarios SET password_hash = $1 WHERE id = $2', [
      hash,
      rows[0].usuario_id,
    ]);
    await cliente.query(
      'UPDATE password_resets SET usado_en = now() WHERE usuario_id = $1 AND usado_en IS NULL',
      [rows[0].usuario_id]
    );

    await cliente.query('COMMIT');
    return res.status(200).json({ mensaje: 'Contraseña actualizada. Ya puedes iniciar sesión' });
  } catch (error) {
    await cliente.query('ROLLBACK');
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    cliente.release();
  }
}

module.exports = { olvidePassword, restablecerPassword };
