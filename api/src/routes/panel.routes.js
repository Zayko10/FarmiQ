const express = require('express');
const c = require('../controllers/panel.controller');
const { requireAuth, requireRol } = require('../middlewares/auth.middleware');
const { cargarBotica } = require('../middlewares/personal.middleware');

const router = express.Router();

// Solo personal de botica: cada quien ve y modifica únicamente su botica
router.use(requireAuth, requireRol('personal'), cargarBotica);

router.get('/resumen', c.resumen);

router.get('/inventario', c.listarInventario);
router.post('/inventario', c.agregarAlInventario);
router.patch('/inventario/:id', c.actualizarInventario);

router.get('/catalogo', c.buscarCatalogo);
router.post('/medicamentos', c.crearMedicamento);
router.patch('/medicamentos/:id/ficha', c.actualizarFicha);

router.get('/reservas', c.listarReservas);
router.post('/reservas/entregar', c.entregarReserva);

module.exports = router;
