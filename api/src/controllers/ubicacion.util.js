// Distancia en km entre el cliente (lat, lng) y una botica "b" (fórmula de Haversine)
const distanciaSql = (pLat, pLng) => `
  (6371 * 2 * asin(sqrt(
      power(sin(radians(b.latitud::float8 - ${pLat}) / 2), 2) +
      cos(radians(${pLat})) * cos(radians(b.latitud::float8)) *
      power(sin(radians(b.longitud::float8 - ${pLng}) / 2), 2)
  )))`;

const AVISO_UBICACION = {
  mensaje:
    'Necesitamos tu ubicación para calcular qué botica te queda más cerca. Actívala para ver las distancias.',
  accion: 'activar_ubicacion',
};

function detallesDeError(error) {
  return error.issues.map((p) => ({ campo: p.path.join('.'), mensaje: p.message }));
}

module.exports = { distanciaSql, AVISO_UBICACION, detallesDeError };
