// Reglas de negocio configurables por variables de entorno (se leen al usarse, no al cargar el archivo)
const numero = (valor, porDefecto) => {
  const n = Number(valor);
  return Number.isFinite(n) && n > 0 ? n : porDefecto;
};

module.exports = {
  // Login: intentos fallidos seguidos antes de bloquear y duración del bloqueo
  loginMaxIntentos: () => numero(process.env.LOGIN_MAX_INTENTOS, 5),
  loginBloqueoMinutos: () => numero(process.env.LOGIN_BLOQUEO_MINUTOS, 15),
  // Reservas: minutos para pagar antes de que el stock se libere
  reservaMinutos: () => numero(process.env.RESERVA_MINUTOS, 15),
  reservaMaxActivas: () => numero(process.env.RESERVA_MAX_ACTIVAS, 3),
  reservaMaxCantidad: () => numero(process.env.RESERVA_MAX_CANTIDAD, 5),
};
