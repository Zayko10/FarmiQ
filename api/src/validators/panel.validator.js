const { z } = require('zod');

const textoOpcional = (max) =>
  z.string().trim().max(max, `No puede superar ${max} caracteres`).optional().or(z.literal(''));

const stock = z.coerce
  .number({ error: 'El stock debe ser un número' })
  .int('El stock debe ser un número entero')
  .min(0, 'El stock no puede ser negativo')
  .max(100000, 'El stock es demasiado alto');

const precio = z.coerce
  .number({ error: 'El precio debe ser un número' })
  .min(0, 'El precio no puede ser negativo')
  .max(9999.99, 'El precio es demasiado alto');

const idNumerico = (mensaje) => z.string().regex(/^\d{1,15}$/, mensaje);

const filtroInventarioSchema = z.object({
  q: z.string().trim().max(100).optional(),
  filtro: z.enum(['todos', 'sin_stock', 'bajo', 'desactualizados']).default('todos'),
});

const idMedicamentoSchema = z.object({ id: idNumerico('El identificador del medicamento no es válido') });

const actualizarInventarioSchema = z
  .object({ stock: stock.optional(), precio: precio.optional() })
  .refine((d) => d.stock !== undefined || d.precio !== undefined, 'Envía el stock, el precio o ambos');

const agregarInventarioSchema = z.object({
  medicamento_id: z.coerce.number({ error: 'El medicamento no es válido' }).int().positive(),
  stock,
  precio,
});

const fichaCampos = {
  dosis_referencial: textoOpcional(500),
  descripcion: textoOpcional(500),
  indicaciones: textoOpcional(600),
  contraindicaciones: textoOpcional(600),
  efectos_adversos: textoOpcional(600),
  conservacion: textoOpcional(300),
  laboratorio: textoOpcional(100),
  prospecto_url: z.string().trim().url('El enlace del prospecto no es válido').max(500).optional().or(z.literal('')),
};

const nuevoMedicamentoSchema = z.object({
  nombre: z.string().trim().min(2, 'El nombre es obligatorio').max(120),
  principio_activo: z.string().trim().min(2, 'El principio activo es obligatorio').max(150),
  concentracion: z.string().trim().min(1, 'La concentración es obligatoria').max(60),
  presentacion: z.string().trim().min(2, 'La presentación es obligatoria').max(80),
  categoria: z.string().trim().min(2, 'La categoría es obligatoria').max(60),
  es_generico: z.boolean().default(false),
  requiere_receta: z.boolean().default(false),
  ...fichaCampos,
  stock,
  precio,
});

const fichaSchema = z
  .object(fichaCampos)
  .refine((d) => Object.keys(d).length > 0, 'Envía al menos un campo para actualizar');

const catalogoSchema = z.object({ q: z.string().trim().min(2, 'Escribe al menos 2 caracteres').max(100) });

const estadoReservasSchema = z.object({
  estado: z.enum(['activas', 'pendiente_pago', 'pagada', 'entregada', 'todas']).default('activas'),
});

module.exports = {
  filtroInventarioSchema,
  idMedicamentoSchema,
  actualizarInventarioSchema,
  agregarInventarioSchema,
  nuevoMedicamentoSchema,
  fichaSchema,
  catalogoSchema,
  estadoReservasSchema,
};
