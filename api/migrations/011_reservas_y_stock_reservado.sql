-- Reservas con pago dentro de 15 minutos.
-- stock           = unidades físicas en la botica.
-- stock_reservado = unidades "separadas" por reservas pendientes de pago.
-- Disponible para la venta = stock - stock_reservado.
ALTER TABLE inventario
  ADD COLUMN stock_reservado INTEGER NOT NULL DEFAULT 0,
  ADD CONSTRAINT inventario_reservado_valido
    CHECK (stock_reservado >= 0 AND stock_reservado <= stock);

CREATE TABLE reservas (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id      BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  botica_id       BIGINT NOT NULL REFERENCES boticas(id),
  medicamento_id  BIGINT NOT NULL REFERENCES medicamentos(id),
  cantidad        INTEGER NOT NULL,
  precio_unitario NUMERIC(8,2) NOT NULL,
  total           NUMERIC(10,2) NOT NULL,
  estado          TEXT NOT NULL DEFAULT 'pendiente_pago',
  codigo          TEXT NOT NULL UNIQUE,
  expira_en       TIMESTAMPTZ NOT NULL,
  metodo_pago     TEXT,
  pago_referencia TEXT,
  pagada_en       TIMESTAMPTZ,
  entregada_en    TIMESTAMPTZ,
  cancelada_en    TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT reservas_cantidad_valida CHECK (cantidad > 0),
  CONSTRAINT reservas_estado_valido CHECK (estado IN
    ('pendiente_pago', 'pagada', 'entregada', 'expirada', 'cancelada'))
);

CREATE INDEX reservas_usuario_idx ON reservas (usuario_id, creado_en DESC);
CREATE INDEX reservas_botica_idx  ON reservas (botica_id, estado);
-- Acelera el barrido de reservas vencidas
CREATE INDEX reservas_vencimiento_idx ON reservas (expira_en) WHERE estado = 'pendiente_pago';
