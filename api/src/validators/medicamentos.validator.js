const { z } = require('zod');

const busquedaSchema = z.object({
  q: z
    .string({ error: 'Escribe el nombre o el principio activo del medicamento' })
    .trim()
    .min(2, 'Escribe al menos 2 caracteres')
    .max(100, 'La búsqueda no puede superar 100 caracteres'),
});

const idSchema = z.object({
  id: z
    .string()
    .regex(/^\d{1,15}$/, 'El identificador del medicamento no es válido'),
});

module.exports = { busquedaSchema, idSchema };
