const express = require('express');
const { buscarMedicamentos } = require('../controllers/medicamentos.controller');
const { obtenerAlternativas } = require('../controllers/alternativas.controller');

const router = express.Router();

// Público: un invitado puede buscar y comparar sin iniciar sesión
router.get('/', buscarMedicamentos);
router.get('/:id/alternativas', obtenerAlternativas);

module.exports = router;
