const express = require('express');
const { buscarMedicamentos } = require('../controllers/medicamentos.controller');
const { obtenerAlternativas } = require('../controllers/alternativas.controller');
const { obtenerDisponibilidad } = require('../controllers/disponibilidad.controller');
const { obtenerDetalle } = require('../controllers/detalle.controller');
const { authOpcional } = require('../middlewares/auth.middleware');

const router = express.Router();

// Público: un invitado puede buscar, comparar, ver la ficha y la disponibilidad sin iniciar sesión
router.get('/', buscarMedicamentos);
router.get('/:id/alternativas', obtenerAlternativas);
router.get('/:id/disponibilidad', obtenerDisponibilidad);
// Si hay sesión, el detalle indica si el medicamento es favorito del cliente
router.get('/:id', authOpcional, obtenerDetalle);

module.exports = router;
