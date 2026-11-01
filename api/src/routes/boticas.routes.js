const express = require('express');
const { listarBoticas } = require('../controllers/boticas.controller');

const router = express.Router();

// Público: el invitado puede explorar las sedes
router.get('/', listarBoticas);

module.exports = router;
