const express = require('express');
const cors = require('cors');
const pool = require('./db');

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

module.exports = app;