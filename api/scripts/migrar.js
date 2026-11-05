require('dotenv').config();
const fs = require('fs');
const path = require('path');
const pool = require('../src/db');

async function migrar() {
  await pool.query(
    'CREATE TABLE IF NOT EXISTS migraciones (' +
      'nombre TEXT PRIMARY KEY, ' +
      'aplicada_en TIMESTAMPTZ NOT NULL DEFAULT now())'
  );

  const carpeta = path.join(__dirname, '..', 'migrations');
  const archivos = fs.readdirSync(carpeta).filter((f) => f.endsWith('.sql')).sort();

  const { rows } = await pool.query('SELECT nombre FROM migraciones');
  const aplicadas = new Set(rows.map((r) => r.nombre));

  for (const archivo of archivos) {
    if (aplicadas.has(archivo)) {
      console.log('- ' + archivo + ' (ya aplicada)');
      continue;
    }

    const sql = fs.readFileSync(path.join(carpeta, archivo), 'utf8');
    const cliente = await pool.connect();
    try {
      await cliente.query('BEGIN');
      await cliente.query(sql);
      await cliente.query('INSERT INTO migraciones (nombre) VALUES ($1)', [archivo]);
      await cliente.query('COMMIT');
      console.log('+ ' + archivo + ' aplicada');
    } catch (error) {
      await cliente.query('ROLLBACK');
      console.error('x ' + archivo + ' falló: ' + error.message);
      process.exitCode = 1;
      break;
    } finally {
      cliente.release();
    }
  }

  await pool.end();
}

migrar();