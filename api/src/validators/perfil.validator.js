const { z } = require('zod');

const perfilSchema = z
  .object({
    nombre: z.string().trim().min(2, 'El nombre debe tener al menos 2 caracteres').max(100).optional(),
    telefono: z
      .string()
      .trim()
      .regex(/^9\d{8}$/, 'El teléfono debe tener 9 dígitos y empezar con 9')
      .or(z.literal(''))
      .optional(),
    direccion: z.string().trim().max(200, 'La dirección no puede superar 200 caracteres').optional(),
  })
  .refine((datos) => Object.keys(datos).length > 0, 'Envía al menos un campo para actualizar');

module.exports = { perfilSchema };
