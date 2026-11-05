const express = require('express');
const { listarBoticas, obtenerBotica, productosDeBotica } = require('../controllers/boticas.controller');

const router = express.Router();

// Público: el invitado puede explorar las sedes, ver su stock y comparar cercanía
router.get('/', listarBoticas);
router.get('/:id/productos', productosDeBotica);
router.get('/:id', obtenerBotica);

module.exports = router;
