const express = require('express');
const { obtenerPerfil, actualizarPerfil } = require('../controllers/perfil.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

const router = express.Router();

router.get('/', requireAuth, obtenerPerfil);
router.patch('/', requireAuth, actualizarPerfil);

module.exports = router;
