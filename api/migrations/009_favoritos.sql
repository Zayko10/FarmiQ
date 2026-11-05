-- HU17: medicamentos favoritos del cliente
CREATE TABLE favoritos (
  usuario_id     BIGINT NOT NULL REFERENCES usuarios(id)     ON DELETE CASCADE,
  medicamento_id BIGINT NOT NULL REFERENCES medicamentos(id) ON DELETE CASCADE,
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (usuario_id, medicamento_id)
);
