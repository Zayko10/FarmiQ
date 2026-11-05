const express = require('express');
const { registrar, login, loginPersonal } = require('../controllers/auth.controller');
const { olvidePassword, restablecerPassword } = require('../controllers/recuperacion.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

const router = express.Router();

router.post('/registro', registrar);
router.post('/login', login);
router.post('/login-personal', loginPersonal);
router.post('/olvide-password', olvidePassword);
router.post('/restablecer-password', restablecerPassword);

router.get('/yo', requireAuth, (req, res) => {
  res.json({ usuario: req.usuario });
});

module.exports = router;
