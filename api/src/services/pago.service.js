const crypto = require('crypto');

// PASARELA DE PAGO SIMULADA.
// Al integrar una pasarela real (Culqi, Niubiz, Izipay, Yape Empresas...) se reemplaza el cuerpo de
// esta función. Los datos de la tarjeta NUNCA se guardan: solo la referencia y un texto enmascarado.
//   - Tarjeta cuyo número termina en 0000  -> rechazada (para probar el error)
//   - Yape/Plin cuyo celular termina en 000 -> rechazado
//   - Cualquier otro dato                   -> aprobado
async function procesarPago({ metodo, datos, monto }) {
  if (!(monto > 0)) return { aprobado: false, motivo: 'El monto no es válido' };

  if (metodo === 'tarjeta') {
    const numero = datos.numero_tarjeta;
    if (numero.endsWith('0000')) {
      return { aprobado: false, motivo: 'El banco rechazó la tarjeta. Prueba con otra o usa otro método de pago.' };
    }
    return aprobar('Tarjeta •••• ' + numero.slice(-4));
  }

  const celular = datos.celular;
  if (celular.endsWith('000')) {
    return { aprobado: false, motivo: 'No se pudo confirmar el pago. Revisa tu aplicación e inténtalo de nuevo.' };
  }
  const nombre = metodo === 'yape' ? 'Yape' : 'Plin';
  return aprobar(nombre + ' ' + celular.slice(0, 1) + '•••••' + celular.slice(-3));
}

function aprobar(descripcion) {
  return {
    aprobado: true,
    referencia: 'SIM-' + crypto.randomBytes(5).toString('hex').toUpperCase(),
    descripcion,
  };
}

module.exports = { procesarPago };
