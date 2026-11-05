const pool = require('../db');

// Libera las reservas cuyo plazo de pago venció: las marca como "expirada" y devuelve
// las unidades al stock disponible. Es seguro llamarla muchas veces y desde varios procesos a la vez.
async function liberarVencidas(db = pool) {
  const { rowCount } = await db.query(
    `WITH vencidas AS (
       UPDATE reservas
          SET estado = 'expirada'
        WHERE estado = 'pendiente_pago' AND expira_en <= now()
        RETURNING botica_id, medicamento_id, cantidad
     ), por_producto AS (
       SELECT botica_id, medicamento_id, SUM(cantidad)::int AS cantidad
         FROM vencidas
        GROUP BY botica_id, medicamento_id
     )
     UPDATE inventario i
        SET stock_reservado = GREATEST(0, i.stock_reservado - p.cantidad)
       FROM por_producto p
      WHERE i.botica_id = p.botica_id AND i.medicamento_id = p.medicamento_id`
  );
  return rowCount;
}

// Consulta común de una reserva con los datos de la botica y del medicamento
const SELECT_RESERVA = `
  SELECT r.id, r.estado, r.cantidad,
         r.precio_unitario::float8 AS precio_unitario,
         r.total::float8           AS total,
         r.creado_en, r.expira_en, r.pagada_en, r.entregada_en, r.metodo_pago,
         CASE WHEN r.estado = 'pendiente_pago'
              THEN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (r.expira_en - now()))))::int
              ELSE 0 END AS segundos_restantes,
         CASE WHEN r.estado IN ('pagada', 'entregada') THEN r.codigo END AS codigo,
         b.id AS botica_id, b.nombre AS botica_nombre, b.direccion AS botica_direccion,
         b.latitud::float8 AS botica_latitud, b.longitud::float8 AS botica_longitud,
         m.id AS medicamento_id, m.nombre AS medicamento_nombre,
         m.concentracion, m.presentacion, m.requiere_receta
    FROM reservas r
    JOIN boticas b ON b.id = r.botica_id
    JOIN medicamentos m ON m.id = r.medicamento_id`;

module.exports = { liberarVencidas, SELECT_RESERVA };
