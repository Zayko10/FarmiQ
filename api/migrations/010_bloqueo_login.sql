-- Bloqueo temporal del login: 5 contraseñas incorrectas seguidas para un mismo correo.
-- Se guarda por correo (exista o no la cuenta) para no revelar qué correos están registrados.
CREATE TABLE login_intentos (
  email           TEXT PRIMARY KEY,
  intentos        INTEGER NOT NULL DEFAULT 0,
  bloqueado_hasta TIMESTAMPTZ,
  ultimo_intento  TIMESTAMPTZ NOT NULL DEFAULT now()
);
