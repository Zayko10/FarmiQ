const pool = require('../db');
const { liberarVencidas } = require('../services/reservas.service');
const {
  filtroInventarioSchema,
  idMedicamentoSchema,
  actualizarInventarioSchema,
  agregarInventarioSchema,
  nuevoMedicamentoSchema,
  fichaSchema,
  catalogoSchema,
  estadoReservasSchema,
} = require('../validators/panel.validator');
const { codigoSchema } = require('../validators/reservas.validator');
const { detallesDeError } = require('./ubicacion.util');

const STOCK_BAJO = 5; // unidades disponibles o menos = "stock bajo"
const HORAS_DESACTUALIZADO = 24; // HU27: sin actualizar por más de 24 h

const error500 = (res, error) => {
  console.error(error);
  return res.status(500).json({ error: 'Error interno del servidor' });
};

const invalido = (res, ...errores) =>
  res.status(400).json({
    error: 'Datos inválidos',
    detalles: errores.flatMap((e) => detallesDeError(e)),
  });

const escaparLike = (texto) => texto.replace(/[\\%_]/g, (c) => '\\' + c);

// Columnas de una línea de inventario con los datos del medicamento
const SELECT_INVENTARIO = `
  SELECT m.id AS medicamento_id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
         m.categoria, m.es_generico, m.requiere_receta,
         i.stock, i.stock_reservado, (i.stock - i.stock_reservado) AS disponible,
         i.precio::float8 AS precio, i.actualizado_en,
         FLOOR(EXTRACT(EPOCH FROM (now() - i.actualizado_en)) / 60)::int AS minutos_desde_actualizacion,
         (i.actualizado_en < now() - interval '${HORAS_DESACTUALIZADO} hours') AS desactualizado
    FROM inventario i
    JOIN medicamentos m ON m.id = i.medicamento_id AND m.activo`;

// ---------------------------------------------------------------- Resumen
async function resumen(req, res) {
  try {
    await liberarVencidas();
    const inv = await pool.query(
      `SELECT count(*)::int AS productos,
              count(*) FILTER (WHERE stock - stock_reservado <= 0)::int AS sin_stock,
              count(*) FILTER (WHERE stock - stock_reservado > 0 AND stock - stock_reservado <= $2)::int AS stock_bajo,
              count(*) FILTER (WHERE actualizado_en < now() - interval '${HORAS_DESACTUALIZADO} hours')::int AS desactualizados,
              COALESCE(sum(stock_reservado), 0)::int AS unidades_reservadas
         FROM inventario
        WHERE botica_id = $1`,
      [req.botica.id, STOCK_BAJO]
    );
    const res_ = await pool.query(
      `SELECT count(*) FILTER (WHERE estado = 'pendiente_pago')::int AS pendientes_pago,
              count(*) FILTER (WHERE estado = 'pagada')::int AS por_entregar,
              count(*) FILTER (WHERE estado = 'entregada'
                  AND (entregada_en AT TIME ZONE 'America/Lima')::date = (now() AT TIME ZONE 'America/Lima')::date)::int AS entregadas_hoy,
              COALESCE(sum(total) FILTER (WHERE estado IN ('pagada', 'entregada')
                  AND (pagada_en AT TIME ZONE 'America/Lima')::date = (now() AT TIME ZONE 'America/Lima')::date), 0)::float8 AS ventas_hoy
         FROM reservas
        WHERE botica_id = $1`,
      [req.botica.id]
    );
    return res.status(200).json({
      botica: req.botica,
      inventario: inv.rows[0],
      reservas: res_.rows[0],
      umbral_stock_bajo: STOCK_BAJO,
    });
  } catch (error) {
    return error500(res, error);
  }
}

// ------------------------------------------------------------- Inventario
async function listarInventario(req, res) {
  const f = filtroInventarioSchema.safeParse(req.query);
  if (!f.success) return invalido(res, f.error);

  const params = [req.botica.id];
  const condiciones = [];
  if (f.data.q) {
    params.push('%' + escaparLike(f.data.q) + '%');
    condiciones.push(
      `(unaccent(m.nombre) ILIKE unaccent($${params.length}) OR unaccent(m.principio_activo) ILIKE unaccent($${params.length}))`
    );
  }
  if (f.data.filtro === 'sin_stock') condiciones.push('(i.stock - i.stock_reservado) <= 0');
  if (f.data.filtro === 'bajo') {
    params.push(STOCK_BAJO);
    condiciones.push(`(i.stock - i.stock_reservado) > 0 AND (i.stock - i.stock_reservado) <= $${params.length}`);
  }
  if (f.data.filtro === 'desactualizados') {
    condiciones.push(`i.actualizado_en < now() - interval '${HORAS_DESACTUALIZADO} hours'`);
  }

  try {
    await liberarVencidas();
    const { rows } = await pool.query(
      `${SELECT_INVENTARIO}
        WHERE i.botica_id = $1 ${condiciones.length ? 'AND ' + condiciones.join(' AND ') : ''}
        ORDER BY m.categoria, m.nombre
        LIMIT 300`,
      params
    );
    return res.status(200).json({ productos: rows, umbral_stock_bajo: STOCK_BAJO });
  } catch (error) {
    return error500(res, error);
  }
}

// HU27: actualizar stock y/o precio de un producto de la botica
async function actualizarInventario(req, res) {
  const id = idMedicamentoSchema.safeParse(req.params);
  const cuerpo = actualizarInventarioSchema.safeParse(req.body);
  if (!id.success || !cuerpo.success) {
    return invalido(res, ...[id, cuerpo].filter((r) => !r.success).map((r) => r.error));
  }

  const { stock, precio } = cuerpo.data;
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventario
          SET stock = COALESCE($1::int, stock),
              precio = COALESCE($2::numeric, precio),
              actualizado_en = now()
        WHERE botica_id = $3 AND medicamento_id = $4
          AND COALESCE($1::int, stock) >= stock_reservado`,
      [stock ?? null, precio ?? null, req.botica.id, id.data.id]
    );

    if (rowCount === 0) {
      const actual = await pool.query(
        'SELECT stock_reservado FROM inventario WHERE botica_id = $1 AND medicamento_id = $2',
        [req.botica.id, id.data.id]
      );
      if (!actual.rows[0]) return res.status(404).json({ error: 'Ese producto no está en tu inventario' });
      return res.status(409).json({
        error: `No puedes dejar el stock por debajo de lo reservado (${actual.rows[0].stock_reservado} unidades reservadas por clientes)`,
        stock_reservado: actual.rows[0].stock_reservado,
      });
    }

    const { rows } = await pool.query(`${SELECT_INVENTARIO} WHERE i.botica_id = $1 AND i.medicamento_id = $2`, [
      req.botica.id,
      id.data.id,
    ]);
    return res.status(200).json({ producto: rows[0] });
  } catch (error) {
    return error500(res, error);
  }
}

// Busca en el catálogo productos que la botica todavía no tiene en su inventario
async function buscarCatalogo(req, res) {
  const q = catalogoSchema.safeParse(req.query);
  if (!q.success) return invalido(res, q.error);

  try {
    const { rows } = await pool.query(
      `SELECT m.id AS medicamento_id, m.nombre, m.principio_activo, m.concentracion, m.presentacion,
              m.categoria, m.es_generico, m.requiere_receta
         FROM medicamentos m
        WHERE m.activo
          AND NOT EXISTS (SELECT 1 FROM inventario i WHERE i.medicamento_id = m.id AND i.botica_id = $1)
          AND (unaccent(m.nombre) ILIKE unaccent($2) OR unaccent(m.principio_activo) ILIKE unaccent($2))
        ORDER BY m.nombre
        LIMIT 30`,
      [req.botica.id, '%' + escaparLike(q.data.q) + '%']
    );
    return res.status(200).json({ productos: rows });
  } catch (error) {
    return error500(res, error);
  }
}

// Agrega a la botica un producto que ya existe en el catálogo
async function agregarAlInventario(req, res) {
  const d = agregarInventarioSchema.safeParse(req.body);
  if (!d.success) return invalido(res, d.error);

  try {
    const med = await pool.query('SELECT id FROM medicamentos WHERE id = $1 AND activo', [d.data.medicamento_id]);
    if (!med.rows[0]) return res.status(404).json({ error: 'Medicamento no encontrado' });

    const { rowCount } = await pool.query(
      `INSERT INTO inventario (botica_id, medicamento_id, stock, precio)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT DO NOTHING`,
      [req.botica.id, d.data.medicamento_id, d.data.stock, d.data.precio]
    );
    if (rowCount === 0) return res.status(409).json({ error: 'Ese producto ya está en tu inventario' });

    const { rows } = await pool.query(`${SELECT_INVENTARIO} WHERE i.botica_id = $1 AND i.medicamento_id = $2`, [
      req.botica.id,
      d.data.medicamento_id,
    ]);
    return res.status(201).json({ producto: rows[0] });
  } catch (error) {
    return error500(res, error);
  }
}

// Crea un producto nuevo en el catálogo y lo deja en el inventario de la botica
async function crearMedicamento(req, res) {
  const d = nuevoMedicamentoSchema.safeParse(req.body);
  if (!d.success) return invalido(res, d.error);

  const v = d.data;
  const vacioANull = (t) => (t === undefined || t === '' ? null : t);
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const nuevo = await cliente.query(
      `INSERT INTO medicamentos
         (nombre, principio_activo, concentracion, presentacion, categoria, es_generico, requiere_receta,
          dosis_referencial, descripcion, indicaciones, contraindicaciones, efectos_adversos,
          conservacion, laboratorio, prospecto_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       RETURNING id`,
      [
        v.nombre, v.principio_activo, v.concentracion, v.presentacion, v.categoria,
        v.es_generico, v.requiere_receta,
        vacioANull(v.dosis_referencial), vacioANull(v.descripcion), vacioANull(v.indicaciones),
        vacioANull(v.contraindicaciones), vacioANull(v.efectos_adversos), vacioANull(v.conservacion),
        vacioANull(v.laboratorio), vacioANull(v.prospecto_url),
      ]
    );
    await cliente.query(
      'INSERT INTO inventario (botica_id, medicamento_id, stock, precio) VALUES ($1, $2, $3, $4)',
      [req.botica.id, nuevo.rows[0].id, v.stock, v.precio]
    );
    await cliente.query('COMMIT');

    const { rows } = await pool.query(`${SELECT_INVENTARIO} WHERE i.botica_id = $1 AND i.medicamento_id = $2`, [
      req.botica.id,
      nuevo.rows[0].id,
    ]);
    return res.status(201).json({ producto: rows[0] });
  } catch (error) {
    await cliente.query('ROLLBACK').catch(() => {});
    if (error.code === '23505') {
      return res.status(409).json({
        error: 'Ya existe un producto con ese nombre, concentración y presentación. Búscalo en el catálogo y agrégalo a tu inventario.',
      });
    }
    return error500(res, error);
  } finally {
    cliente.release();
  }
}

// Completa o corrige la ficha técnica de un producto que la botica vende
async function actualizarFicha(req, res) {
  const id = idMedicamentoSchema.safeParse(req.params);
  const cuerpo = fichaSchema.safeParse(req.body);
  if (!id.success || !cuerpo.success) {
    return invalido(res, ...[id, cuerpo].filter((r) => !r.success).map((r) => r.error));
  }

  const permitidos = Object.keys(cuerpo.data);
  const sets = permitidos.map((campo, i) => `${campo} = $${i + 3}`);
  const valores = permitidos.map((campo) => (cuerpo.data[campo] === '' ? null : cuerpo.data[campo]));

  try {
    const { rowCount } = await pool.query(
      `UPDATE medicamentos m
          SET ${sets.join(', ')}
        WHERE m.id = $1 AND m.activo
          AND EXISTS (SELECT 1 FROM inventario i WHERE i.medicamento_id = m.id AND i.botica_id = $2)`,
      [id.data.id, req.botica.id, ...valores]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'Ese producto no está en tu inventario' });
    return res.status(200).json({ actualizado: true });
  } catch (error) {
    return error500(res, error);
  }
}

// --------------------------------------------------------------- Reservas
const SELECT_RESERVAS_PANEL = `
  SELECT r.id, r.estado, r.cantidad, r.precio_unitario::float8 AS precio_unitario, r.total::float8 AS total,
         r.codigo, r.creado_en, r.expira_en, r.pagada_en, r.entregada_en, r.metodo_pago,
         CASE WHEN r.estado = 'pendiente_pago'
              THEN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (r.expira_en - now()))))::int ELSE 0 END AS segundos_restantes,
         u.nombre AS cliente_nombre, u.telefono AS cliente_telefono,
         m.id AS medicamento_id, m.nombre AS medicamento_nombre, m.concentracion, m.presentacion, m.requiere_receta
    FROM reservas r
    JOIN usuarios u ON u.id = r.usuario_id
    JOIN medicamentos m ON m.id = r.medicamento_id`;

async function listarReservas(req, res) {
  const f = estadoReservasSchema.safeParse(req.query);
  if (!f.success) return invalido(res, f.error);

  const filtros = {
    activas: "AND r.estado IN ('pendiente_pago', 'pagada')",
    pendiente_pago: "AND r.estado = 'pendiente_pago'",
    pagada: "AND r.estado = 'pagada'",
    entregada: "AND r.estado = 'entregada'",
    todas: '',
  };

  try {
    await liberarVencidas();
    const { rows } = await pool.query(
      `${SELECT_RESERVAS_PANEL}
        WHERE r.botica_id = $1 ${filtros[f.data.estado]}
        ORDER BY (r.estado = 'pendiente_pago') DESC, r.creado_en DESC
        LIMIT 100`,
      [req.botica.id]
    );
    return res.status(200).json({ reservas: rows });
  } catch (error) {
    return error500(res, error);
  }
}

// El cliente llega a la botica, muestra su código y el personal registra la entrega
async function entregarReserva(req, res) {
  const d = codigoSchema.safeParse(req.body);
  if (!d.success) return invalido(res, d.error);

  try {
    const { rows } = await pool.query(
      `UPDATE reservas
          SET estado = 'entregada', entregada_en = now()
        WHERE botica_id = $1 AND codigo = $2 AND estado = 'pagada'
        RETURNING id`,
      [req.botica.id, d.data.codigo]
    );
    if (!rows[0]) {
      const previa = await pool.query('SELECT estado FROM reservas WHERE botica_id = $1 AND codigo = $2', [
        req.botica.id,
        d.data.codigo,
      ]);
      const estado = previa.rows[0] && previa.rows[0].estado;
      const mensajes = {
        entregada: 'Esta reserva ya fue entregada.',
        pendiente_pago: 'Esta reserva todavía no está pagada.',
        expirada: 'Esta reserva venció sin pago.',
        cancelada: 'Esta reserva fue cancelada.',
      };
      return res.status(estado ? 409 : 404).json({
        error: estado ? mensajes[estado] : 'No encontramos una reserva con ese código en tu botica',
      });
    }
    const { rows: detalle } = await pool.query(`${SELECT_RESERVAS_PANEL} WHERE r.id = $1`, [rows[0].id]);
    return res.status(200).json({ reserva: detalle[0], mensaje: 'Entrega registrada' });
  } catch (error) {
    return error500(res, error);
  }
}

module.exports = {
  resumen,
  listarInventario,
  actualizarInventario,
  buscarCatalogo,
  agregarAlInventario,
  crearMedicamento,
  actualizarFicha,
  listarReservas,
  entregarReserva,
};
