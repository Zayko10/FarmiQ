require('dotenv').config();
const app = require('./app');
const { liberarVencidas } = require('./services/reservas.service');

const PORT = process.env.PORT || 3000;

// Cada 30 segundos se liberan las reservas cuyo plazo de pago (15 min) ya venció.
// Además, cada consulta de reservas y cada pago liberan las vencidas antes de responder.
const INTERVALO_MS = 30 * 1000;

async function barrer() {
  try {
    const n = await liberarVencidas();
    if (n > 0) console.log(`Reservas vencidas liberadas: ${n} producto(s) devueltos al stock`);
  } catch (error) {
    console.error('Error al liberar reservas vencidas:', error.message);
  }
}

app.listen(PORT, () => {
  console.log(`API escuchando en http://localhost:${PORT}`);
  barrer();
  setInterval(barrer, INTERVALO_MS);
});
