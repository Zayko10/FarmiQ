const crypto = require('crypto');
const pool = require('../db');
const config = require('../config');
const { liberarVencidas, SELECT_RESERVA } = require('../services/reservas.service');
const { procesarPago } = require('../services/pago.service');
const {
  crearReservaSchema,
  idReservaSchema,
  pagoSchema,
} = require('../validators/reservas.validator');
const { detallesDeError } = require('./ubicacion.util');

const ALFABETO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0/O/1/I para evitar confusiones

function generarCodigo() {
  let codigo = '';
  for (let i = 0; i < 6; i++) codigo += ALFABETO[crypto.randomInt(ALFABETO.length)];
  return codigo;
}

async function obtenerReservaDeUsuario(db, id, usuarioId) {
  const { rows } = await db.query(SELECT_RESERVA + ' WHERE r.id = $1 AND r.usuario_id = $2', [id, usuarioId]);
  return rows[0];
}

// Crea una reserva y "separa" el stock durante los minutos configurados (15 por defecto)
async function crearReserva(req, res) {
  const datos = crearReservaSchema.safeParse(req.body);
  if (!datos.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(datos.error) });
  }

  const { botica_id, medicamento_id, cantidad } = datos.data;
  const maxCantidad = config.reservaMaxCantidad();
  if (cantidad > maxCantidad) {
    return res.status(400).json({
      error: 'Datos inválidos',
      detalles: [{ campo: 'cantidad', mensaje: `Puedes reservar hasta ${maxCantidad} unidades por pedido` }],
    });
  }

  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    await liberarVencidas(cliente);

    // Evita acaparar stock: límite de reservas pendientes por cliente
    const activas = await cliente.query(
      "SELECT count(*)::int AS n FROM reservas WHERE usuario_id = $1 AND estado = 'pendiente_pago'",
      [req.usuario.id]
    );
    if (activas.rows[0].n >= config.reservaMaxActivas()) {
      await cliente.query('ROLLBACK');
      return res.status(409).json({
        error: `Ya tienes ${activas.rows[0].n} reservas pendientes de pago. Págalas o cancélalas antes de reservar más.`,
      });
    }

    // Separa el stock solo si alcanza (la condición va en el UPDATE para evitar carreras entre clientes)
    const separado = await cliente.query(
      `UPDATE inventario i
          SET stock_reservado = i.stock_reservado + $3
         FROM boticas b, medicamentos m
        WHERE i.botica_id = $1 AND i.medicamento_id = $2
          AND b.id = i.botica_id AND b.activa
          AND m.id = i.medicamento_id AND m.activo
          AND (i.stock - i.stock_reservado) >= $3
        RETURNING i.precio::float8 AS precio`,
      [botica_id, medicamento_id, cantidad]
    );

    if (separado.rowCount === 0) {
      const existe = await cliente.query(
        `SELECT (i.stock - i.stock_reservado) AS disponible
           FROM inventario i
           JOIN boticas b ON b.id = i.botica_id AND b.activa
           JOIN medicamentos m ON m.id = i.medicamento_id AND m.activo
          WHERE i.botica_id = $1 AND i.medicamento_id = $2`,
        [botica_id, medicamento_id]
      );
      await cliente.query('ROLLBACK');
      if (!existe.rows[0]) {
        return res.status(404).json({ error: 'Esa botica no vende este producto' });
      }
      const disp = existe.rows[0].disponible;
      return res.status(409).json({
        error:
          disp > 0
            ? `Solo quedan ${disp} unidades disponibles en esta botica`
            : 'Este producto se quedó sin stock en esta botica',
        disponible: disp,
      });
    }

    const precio = separado.rows[0].precio;
    const total = Math.round(precio * cantidad * 100) / 100;
    const minutos = config.reservaMinutos();

    let id = null;
    for (let intento = 0; intento < 5 && id === null; intento++) {
      try {
        // SAVEPOINT: si el código choca con otro, solo se repite el INSERT
        await cliente.query('SAVEPOINT nueva');
        const ins = await cliente.query(
          `INSERT INTO reservas (usuario_id, botica_id, medicamento_id, cantidad, precio_unitario, total, codigo, expira_en)
           VALUES ($1, $2, $3, $4, $5, $6, $7, now() + ($8::int * interval '1 minute'))
           RETURNING id`,
          [req.usuario.id, botica_id, medicamento_id, cantidad, precio, total, generarCodigo(), minutos]
        );
        id = ins.rows[0].id;
      } catch (error) {
        await cliente.query('ROLLBACK TO SAVEPOINT nueva');
        if (error.code !== '23505') throw error;
      }
    }
    if (id === null) throw new Error('No se pudo generar un código de reserva único');

    await cliente.query('COMMIT');

    const reserva = await obtenerReservaDeUsuario(pool, id, req.usuario.id);
    return res.status(201).json({
      reserva,
      minutos_para_pagar: minutos,
      mensaje: `Separamos tu producto por ${minutos} minutos. Si no pagas en ese tiempo, se libera automáticamente.`,
    });
  } catch (error) {
    await cliente.query('ROLLBACK').catch(() => {});
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    cliente.release();
  }
}

// "Mis reservas": primero las pendientes de pago, luego las más recientes
async function listarReservas(req, res) {
  try {
    await liberarVencidas();
    const { rows } = await pool.query(
      SELECT_RESERVA +
        ` WHERE r.usuario_id = $1
          ORDER BY (r.estado = 'pendiente_pago') DESC, r.creado_en DESC
          LIMIT 50`,
      [req.usuario.id]
    );
    if (rows.length === 0) {
      return res.status(200).json({ reservas: [], mensaje: 'Aún no tienes reservas' });
    }
    return res.status(200).json({ reservas: rows });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

async function obtenerReserva(req, res) {
  const id = idReservaSchema.safeParse(req.params);
  if (!id.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(id.error) });
  }
  try {
    await liberarVencidas();
    const reserva = await obtenerReservaDeUsuario(pool, id.data.id, req.usuario.id);
    if (!reserva) return res.status(404).json({ error: 'Reserva no encontrada' });
    return res.status(200).json({ reserva });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

// Paga una reserva dentro del plazo. El stock ya estaba separado: ahora se descuenta de verdad.
async function pagarReserva(req, res) {
  const id = idReservaSchema.safeParse(req.params);
  const pago = pagoSchema.safeParse(req.body);
  if (!id.success || !pago.success) {
    const detalles = [
      ...(id.success ? [] : detallesDeError(id.error)),
      ...(pago.success ? [] : detallesDeError(pago.error)),
    ];
    return res.status(400).json({ error: 'Datos inválidos', detalles });
  }

  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    await liberarVencidas(cliente);

    const { rows } = await cliente.query(
      'SELECT id, estado, cantidad, total::float8 AS total, botica_id, medicamento_id ' +
        'FROM reservas WHERE id = $1 AND usuario_id = $2 FOR UPDATE',
      [id.data.id, req.usuario.id]
    );
    const reserva = rows[0];

    if (!reserva) {
      await cliente.query('ROLLBACK');
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }
    if (reserva.estado === 'expirada') {
      await cliente.query('COMMIT'); // conserva la liberación hecha arriba
      return res.status(410).json({
        error: 'El tiempo para pagar terminó y el producto fue liberado. Puedes volver a reservarlo si aún hay stock.',
        estado: 'expirada',
      });
    }
    if (reserva.estado !== 'pendiente_pago') {
      await cliente.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta reserva ya no está pendiente de pago', estado: reserva.estado });
    }

    const cobro = await procesarPago({ metodo: pago.data.metodo, datos: pago.data, monto: reserva.total });
    if (!cobro.aprobado) {
      await cliente.query('ROLLBACK');
      return res.status(402).json({ error: cobro.motivo, estado: 'pendiente_pago' });
    }

    await cliente.query(
      `UPDATE inventario
          SET stock = stock - $3, stock_reservado = stock_reservado - $3
        WHERE botica_id = $1 AND medicamento_id = $2`,
      [reserva.botica_id, reserva.medicamento_id, reserva.cantidad]
    );
    await cliente.query(
      `UPDATE reservas
          SET estado = 'pagada', pagada_en = now(), metodo_pago = $2, pago_referencia = $3
        WHERE id = $1`,
      [reserva.id, cobro.descripcion, cobro.referencia]
    );

    await cliente.query('COMMIT');

    const actualizada = await obtenerReservaDeUsuario(pool, reserva.id, req.usuario.id);
    return res.status(200).json({
      reserva: actualizada,
      mensaje: 'Pago confirmado. Presenta tu código de retiro en la botica.',
    });
  } catch (error) {
    await cliente.query('ROLLBACK').catch(() => {});
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    cliente.release();
  }
}

// Cancela una reserva pendiente y devuelve el stock de inmediato
async function cancelarReserva(req, res) {
  const id = idReservaSchema.safeParse(req.params);
  if (!id.success) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: detallesDeError(id.error) });
  }

  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    await liberarVencidas(cliente);

    const { rows } = await cliente.query(
      'SELECT id, estado, cantidad, botica_id, medicamento_id FROM reservas ' +
        'WHERE id = $1 AND usuario_id = $2 FOR UPDATE',
      [id.data.id, req.usuario.id]
    );
    const reserva = rows[0];

    if (!reserva) {
      await cliente.query('ROLLBACK');
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }
    if (reserva.estado !== 'pendiente_pago') {
      await cliente.query('COMMIT');
      const mensajes = {
        pagada: 'Esta reserva ya está pagada. Para anularla acércate a la botica.',
        entregada: 'Esta reserva ya fue entregada.',
        expirada: 'Esta reserva ya venció.',
        cancelada: 'Esta reserva ya estaba cancelada.',
      };
      return res.status(409).json({ error: mensajes[reserva.estado], estado: reserva.estado });
    }

    await cliente.query(
      `UPDATE inventario SET stock_reservado = GREATEST(0, stock_reservado - $3)
        WHERE botica_id = $1 AND medicamento_id = $2`,
      [reserva.botica_id, reserva.medicamento_id, reserva.cantidad]
    );
    await cliente.query("UPDATE reservas SET estado = 'cancelada', cancelada_en = now() WHERE id = $1", [
      reserva.id,
    ]);
    await cliente.query('COMMIT');

    const actualizada = await obtenerReservaDeUsuario(pool, reserva.id, req.usuario.id);
    return res.status(200).json({ reserva: actualizada, mensaje: 'Reserva cancelada. El producto fue liberado.' });
  } catch (error) {
    await cliente.query('ROLLBACK').catch(() => {});
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    cliente.release();
  }
}

module.exports = { crearReserva, listarReservas, obtenerReserva, pagarReserva, cancelarReserva };
