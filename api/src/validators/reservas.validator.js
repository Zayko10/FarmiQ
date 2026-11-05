const { z } = require('zod');

const entero = (mensaje) => z.coerce.number({ error: mensaje }).int(mensaje).positive(mensaje);

const crearReservaSchema = z.object({
  botica_id: entero('La botica no es válida'),
  medicamento_id: entero('El medicamento no es válido'),
  cantidad: entero('La cantidad debe ser un número entero mayor que 0'),
});

const idReservaSchema = z.object({
  id: z.string().regex(/^\d{1,15}$/, 'El identificador de la reserva no es válido'),
});

function vencimientoVigente(texto) {
  const m = /^(0[1-9]|1[0-2])\/(\d{2})$/.exec(texto);
  if (!m) return false;
  const anio = 2000 + Number(m[2]);
  const mes = Number(m[1]);
  const ahora = new Date();
  return anio > ahora.getFullYear() || (anio === ahora.getFullYear() && mes >= ahora.getMonth() + 1);
}

const celular = z.string().trim().regex(/^9\d{8}$/, 'El celular debe tener 9 dígitos y empezar con 9');

const pagoSchema = z.discriminatedUnion('metodo', [
  z.object({
    metodo: z.literal('tarjeta'),
    numero_tarjeta: z
      .string()
      .transform((v) => v.replace(/\s|-/g, ''))
      .pipe(z.string().regex(/^\d{13,19}$/, 'El número de tarjeta no es válido')),
    vencimiento: z.string().trim().refine(vencimientoVigente, 'La fecha de vencimiento no es válida (MM/AA)'),
    cvv: z.string().trim().regex(/^\d{3,4}$/, 'El código de seguridad no es válido'),
  }),
  z.object({ metodo: z.literal('yape'), celular }),
  z.object({ metodo: z.literal('plin'), celular }),
]);

const codigoSchema = z.object({
  codigo: z
    .string({ error: 'Escribe el código de retiro' })
    .trim()
    .toUpperCase()
    .regex(/^[A-Z0-9]{6}$/, 'El código de retiro tiene 6 caracteres'),
});

module.exports = { crearReservaSchema, idReservaSchema, pagoSchema, codigoSchema };
