// En desarrollo imprimimos el correo en consola.
// Al desplegar en AWS se reemplaza el cuerpo de esta función por Amazon SES.
async function enviarCorreo({ para, asunto, texto }) {
  console.log('--- CORREO SIMULADO ---');
  console.log('Para: ' + para);
  console.log('Asunto: ' + asunto);
  console.log(texto);
  console.log('-----------------------');
}

module.exports = { enviarCorreo };
