const express = require('express');
const cors = require('cors');
const pool = require('./db');
const authRoutes = require('./routes/auth.routes');
const perfilRoutes = require('./routes/perfil.routes');
const medicamentosRoutes = require('./routes/medicamentos.routes');
const boticasRoutes = require('./routes/boticas.routes');
const favoritosRoutes = require('./routes/favoritos.routes');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'ok', servicio: 'FarmiQ API' });
});

app.get('/api/v1/health/db', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() AS hora');
    res.json({ status: 'ok', base_de_datos: 'conectada', hora: result.rows[0].hora });
  } catch (error) {
    console.error(error);
    res.status(500).json({ status: 'error', base_de_datos: 'sin conexión' });
  }
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/perfil', perfilRoutes);
app.use('/api/v1/medicamentos', medicamentosRoutes);
app.use('/api/v1/boticas', boticasRoutes);
app.use('/api/v1/favoritos', favoritosRoutes);

module.exports = app;
