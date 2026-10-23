CREATE TABLE boticas (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre    TEXT NOT NULL,
  direccion TEXT NOT NULL,
  latitud   NUMERIC(9,6),
  longitud  NUMERIC(9,6),
  telefono  TEXT,
  activa    BOOLEAN NOT NULL DEFAULT true,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE usuarios (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre             TEXT NOT NULL,
  email              TEXT NOT NULL UNIQUE,
  telefono           TEXT,
  password_hash      TEXT NOT NULL,
  rol                TEXT NOT NULL DEFAULT 'cliente',
  botica_id          BIGINT REFERENCES boticas(id),
  acepto_terminos_en TIMESTAMPTZ NOT NULL,
  creado_en          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT usuarios_rol_valido CHECK (rol IN ('cliente', 'personal', 'admin')),
  CONSTRAINT usuarios_email_minuscula CHECK (email = lower(email)),
  CONSTRAINT usuarios_personal_con_botica CHECK (rol <> 'personal' OR botica_id IS NOT NULL)
);

INSERT INTO boticas (nombre, direccion)
VALUES ('Botica Elna', 'Chorrillos, Lima');
