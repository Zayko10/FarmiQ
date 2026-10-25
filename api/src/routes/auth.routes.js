const express = require('express');
const { registrar, login } = require('../controllers/auth.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

const router = express.Router();

router.post('/registro', registrar);
router.post('/login', login);

router.get('/yo', requireAuth, (req, res) => {
  res.json({ usuario: req.usuario });
});

module.exports = router;
