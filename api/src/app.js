//Traemos las librerias.
const express = require('express');
const cors = require('cors')

//Creamos la aplicación.
const app = express();

app.use(cors())
app.use(express.json())

//Cuando alguien visite la ruta responderá con un JSON. Lo usaremos para comprobar que el servidor está "vivo".
app.get('/api/v1/health', (req, res) =>{
    res.json({ status: 'ok', servicio: 'FarmiQ API'});
});

module.exports = app;