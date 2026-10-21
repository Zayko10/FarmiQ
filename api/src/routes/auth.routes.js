const express = require('express');
const { registrar } = require('../controllers/auth.controller');

const router = express.Router();

router.post('/registro', registrar);

module.exports = router;
