const { z } = require('zod');

const numero = (min, max, mensaje) =>
  z.coerce.number({ error: mensaje }).min(min, mensaje).max(max, mensaje);

const busquedaSchema = z
  .object({
    q: z
      .string({ error: 'Escribe el nombre o el principio activo del medicamento' })
      .trim()
      .min(2, 'Escribe al menos 2 caracteres')
      .max(100, 'La búsqueda no puede superar 100 caracteres'),
    // HU16: ordenamiento y filtros
    orden: z
      .enum(['relevancia', 'precio_asc', 'precio_desc', 'distancia', 'disponibilidad'], {
        error: 'Orden no válido',
      })
      .default('relevancia'),
    solo_stock: z.enum(['true', 'false'], { error: 'solo_stock debe ser true o false' }).optional(),
    distancia_max_km: numero(0.1, 50, 'La distancia máxima debe estar entre 0.1 y 50 km').optional(),
    lat: numero(-90, 90, 'Latitud no válida').optional(),
    lng: numero(-180, 180, 'Longitud no válida').optional(),
  })
  .superRefine((datos, ctx) => {
    const sinUbicacion = datos.lat === undefined || datos.lng === undefined;
    if ((datos.orden === 'distancia' || datos.distancia_max_km !== undefined) && sinUbicacion) {
      ctx.addIssue({
        code: 'custom',
        path: ['lat'],
        message: 'Se necesita la ubicación (lat y lng) para ordenar o filtrar por distancia',
      });
    }
  });

const idSchema = z.object({
  id: z
    .string()
    .regex(/^\d{1,15}$/, 'El identificador del medicamento no es válido'),
});

// HU04: ubicación opcional del cliente (si envía una coordenada debe enviar la otra)
const ubicacionSchema = z
  .object({
    lat: numero(-90, 90, 'Latitud no válida').optional(),
    lng: numero(-180, 180, 'Longitud no válida').optional(),
  })
  .superRefine((datos, ctx) => {
    if ((datos.lat === undefined) !== (datos.lng === undefined)) {
      ctx.addIssue({
        code: 'custom',
        path: [datos.lat === undefined ? 'lat' : 'lng'],
        message: 'Envía lat y lng juntas para calcular la distancia',
      });
    }
  });

module.exports = { busquedaSchema, idSchema, ubicacionSchema };
