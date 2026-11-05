const express = require('express');
const {
  listarFavoritos,
  agregarFavorito,
  quitarFavorito,
} = require('../controllers/favoritos.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

const router = express.Router();

// Solo con sesión iniciada: el invitado recibe 401 y la app le pide iniciar sesión o registrarse
router.get('/', requireAuth, listarFavoritos);
router.put('/:id', requireAuth, agregarFavorito);
router.delete('/:id', requireAuth, quitarFavorito);

module.exports = router;
