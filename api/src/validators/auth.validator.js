const { z } = require('zod');

const registroSchema = z.object({
  nombre: z.string().trim().min(2, 'El nombre debe tener al menos 2 caracteres').max(100),
  email: z.string().trim().toLowerCase().email('El correo no es válido'),
  telefono: z
    .string()
    .trim()
    .regex(/^9\d{8}$/, 'El teléfono debe tener 9 dígitos y empezar con 9')
    .optional()
    .or(z.literal('')),
  password: z
    .string()
    .min(8, 'La contraseña debe tener al menos 8 caracteres')
    .max(72, 'La contraseña no puede superar 72 caracteres'),
  acepta_terminos: z
    .boolean()
    .refine((valor) => valor === true, 'Debes aceptar los términos y condiciones'),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email('El correo no es válido'),
  password: z.string().min(1, 'La contraseña es obligatoria'),
});

module.exports = { registroSchema, loginSchema };
