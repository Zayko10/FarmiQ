CREATE TABLE medicamentos (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre           TEXT NOT NULL,
  principio_activo TEXT NOT NULL,
  concentracion    TEXT NOT NULL,
  presentacion     TEXT NOT NULL,
  categoria        TEXT NOT NULL,
  es_generico      BOOLEAN NOT NULL DEFAULT false,
  requiere_receta  BOOLEAN NOT NULL DEFAULT false,
  prospecto_url    TEXT,
  activo           BOOLEAN NOT NULL DEFAULT true,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT medicamentos_unico UNIQUE (nombre, concentracion, presentacion)
);

CREATE INDEX medicamentos_principio_idx ON medicamentos (lower(principio_activo));
CREATE INDEX medicamentos_nombre_idx ON medicamentos (lower(nombre));

CREATE TABLE inventario (
  botica_id          BIGINT NOT NULL REFERENCES boticas(id) ON DELETE CASCADE,
  medicamento_id     BIGINT NOT NULL REFERENCES medicamentos(id) ON DELETE CASCADE,
  stock              INTEGER NOT NULL DEFAULT 0,
  precio             NUMERIC(8,2) NOT NULL,
  actualizado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (botica_id, medicamento_id),
  CONSTRAINT inventario_stock_no_negativo CHECK (stock >= 0),
  CONSTRAINT inventario_precio_no_negativo CHECK (precio >= 0)
);

CREATE INDEX inventario_medicamento_idx ON inventario (medicamento_id);
