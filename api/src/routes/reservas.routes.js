const express = require('express');
const {
  crearReserva,
  listarReservas,
  obtenerReserva,
  pagarReserva,
  cancelarReserva,
} = require('../controllers/reservas.controller');
const { requireAuth, requireRol } = require('../middlewares/auth.middleware');

const router = express.Router();

// Solo clientes con sesión iniciada
router.use(requireAuth, requireRol('cliente'));

router.post('/', crearReserva);
router.get('/', listarReservas);
router.get('/:id', obtenerReserva);
router.post('/:id/pagar', pagarReserva);
router.post('/:id/cancelar', cancelarReserva);

module.exports = router;
