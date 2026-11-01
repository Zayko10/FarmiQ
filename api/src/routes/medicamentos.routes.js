const express = require('express');
const { buscarMedicamentos } = require('../controllers/medicamentos.controller');
const { obtenerAlternativas } = require('../controllers/alternativas.controller');
const { obtenerDetalle } = require('../controllers/detalle.controller');

const router = express.Router();

// Público: un invitado puede buscar, comparar y ver la ficha sin iniciar sesión
router.get('/', buscarMedicamentos);
router.get('/:id/alternativas', obtenerAlternativas);
router.get('/:id', obtenerDetalle);

module.exports = router;
