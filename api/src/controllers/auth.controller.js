const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { registroSchema, loginSchema } = require('../validators/auth.validator');
const { enviarCorreo } = require('../services/correo.service');
const config = require('../config');

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

// El conteo se reinicia si el bloqueo ya terminó o si el último intento fue hace más de 30 minutos
const REINICIA = `(login_intentos.bloqueado_hasta IS NOT NULL AND login_intentos.bloqueado_hasta <= now())
                  OR login_intentos.ultimo_intento < now() - interval '30 minutes'`;

function respuestaBloqueo(res, segundos, hasta) {
  const minutos = Math.max(1, Math.ceil(segundos / 60));
  return res.status(429).json({
    error:
      'Demasiados intentos fallidos. Por seguridad bloqueamos el acceso temporalmente; ' +
      'vuelve a intentarlo en ' + minutos + (minutos === 1 ? ' minuto.' : ' minutos.'),
    bloqueado: true,
    bloqueado_hasta: hasta,
    segundos_restantes: segundos,
  });
}

// Registra un intento fallido y devuelve cuántos lleva y hasta cuándo está bloqueado (si aplica)
async function registrarFallo(email) {
  const max = config.loginMaxIntentos();
  const { rows } = await pool.query(
    `INSERT INTO login_intentos (email, intentos, bloqueado_hasta, ultimo_intento)
     VALUES ($1, 1, CASE WHEN 1 >= $2::int THEN now() + ($3::int * interval '1 minute') END, now())
     ON CONFLICT (email) DO UPDATE SET
       intentos = CASE WHEN ${REINICIA} THEN 1 ELSE login_intentos.intentos + 1 END,
       bloqueado_hasta = CASE
         WHEN (CASE WHEN ${REINICIA} THEN 1 ELSE login_intentos.intentos + 1 END) >= $2::int
           THEN now() + ($3::int * interval '1 minute')
         ELSE NULL END,
       ultimo_intento = now()
     RETURNING intentos, bloqueado_hasta,
       CEIL(GREATEST(0, EXTRACT(EPOCH FROM (bloqueado_hasta - now()))))::int AS segundos`,
    [email, max, config.loginBloqueoMinutos()]
  );
  return rows[0];
}

// Lógica común del login de clientes y del login de personal de botica
async function autenticar(req, res, rolPermitido) {
  const resultado = loginSchema.safeParse(req.body);

  if (!resultado.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: formatearErrores(resultado.error) });
  }

  const { email, password } = resultado.data;

  try {
    // 1. ¿El correo está bloqueado? Mientras dure el bloqueo ni siquiera se revisa la contraseña
    const bloqueo = await pool.query(
      `SELECT bloqueado_hasta,
              CEIL(EXTRACT(EPOCH FROM (bloqueado_hasta - now())))::int AS segundos
         FROM login_intentos
        WHERE email = $1 AND bloqueado_hasta > now()`,
      [email]
    );
    if (bloqueo.rows[0]) {
      return respuestaBloqueo(res, bloqueo.rows[0].segundos, bloqueo.rows[0].bloqueado_hasta);
    }

    // 2. Se compara siempre, exista o no el usuario, para que el tiempo no delate el correo
    const { rows } = await pool.query(
      'SELECT id, nombre, email, telefono, rol, botica_id, password_hash FROM usuarios WHERE email = $1',
      [email]
    );
    const usuario = rows[0];
    const coincide = await bcrypt.compare(password, usuario ? usuario.password_hash : HASH_FALSO);

    if (!usuario || !coincide) {
      const fallo = await registrarFallo(email);
      const max = config.loginMaxIntentos();

      if (fallo.bloqueado_hasta && fallo.segundos > 0) {
        if (usuario) {
          // Aviso por correo (en desarrollo se imprime en consola)
          await enviarCorreo({
            para: email,
            asunto: 'Bloqueamos temporalmente el acceso a tu cuenta de FarmiQ',
            texto:
              'Hola ' + usuario.nombre + ', detectamos ' + max + ' intentos fallidos de inicio de sesión. ' +
              'Por seguridad bloqueamos el acceso por ' + config.loginBloqueoMinutos() + ' minutos. ' +
              'Si no fuiste tú, restablece tu contraseña desde la opción "¿Olvidaste tu contraseña?".',
          });
        }
        return respuestaBloqueo(res, fallo.segundos, fallo.bloqueado_hasta);
      }

      return res.status(401).json({
        error: 'Correo o contraseña incorrectos',
        intentos_restantes: Math.max(0, max - fallo.intentos),
      });
    }

    // 3. Credenciales correctas, pero en la puerta equivocada (cliente vs. personal)
    if (usuario.rol !== rolPermitido) {
      return res.status(403).json({
        error:
          rolPermitido === 'cliente'
            ? 'Esta cuenta es de personal de botica. Usa el acceso para personal.'
            : 'Esta cuenta no es de personal de botica. Inicia sesión como cliente.',
      });
    }

    await pool.query('DELETE FROM login_intentos WHERE email = $1', [email]);

    const token = jwt.sign(
      { sub: String(usuario.id), rol: usuario.rol },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    delete usuario.password_hash;

    if (usuario.rol === 'personal') {
      const botica = await pool.query('SELECT nombre FROM boticas WHERE id = $1', [usuario.botica_id]);
      usuario.botica_nombre = botica.rows[0] ? botica.rows[0].nombre : null;
    }

    return res.status(200).json({ token, usuario });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

const login = (req, res) => autenticar(req, res, 'cliente');
const loginPersonal = (req, res) => autenticar(req, res, 'personal');

module.exports = { registrar, login, loginPersonal };
