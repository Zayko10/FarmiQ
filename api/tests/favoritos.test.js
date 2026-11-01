const request = require('supertest');
const app = require('../src/app');
const pool = require('../src/db');

const sufijo = Date.now();
const password = 'clave12345';
let tokenA;
let tokenB;

async function idDe(nombre) {
  const { rows } = await pool.query('SELECT id FROM medicamentos WHERE nombre = $1', [nombre]);
  return rows[0].id;
}

async function crearUsuario(letra) {
  const email = `hu17-test-${letra}-${sufijo}@correo.com`;
  await request(app).post('/api/v1/auth/registro').send({
    nombre: 'Cliente Favoritos ' + letra,
    email,
    password,
    acepta_terminos: true,
  });
  const login = await request(app).post('/api/v1/auth/login').send({ email, password });
  return login.body.token;
}

const con = (token) => (req) => req.set('Authorization', 'Bearer ' + token);

beforeAll(async () => {
  tokenA = await crearUsuario('a');
  tokenB = await crearUsuario('b');
});

afterAll(async () => {
  // Al borrar el usuario se borran sus favoritos (ON DELETE CASCADE)
  await pool.query("DELETE FROM usuarios WHERE email LIKE 'hu17-test-%'");
  await pool.end();
});

describe('Favoritos (HU17)', () => {
  it('Escenario 2: el invitado no puede ver, agregar ni quitar favoritos (401)', async () => {
    const id = await idDe('Panadol Forte');

    const lista = await request(app).get('/api/v1/favoritos');
    const agregar = await request(app).put(`/api/v1/favoritos/${id}`);
    const quitar = await request(app).delete(`/api/v1/favoritos/${id}`);

    expect(lista.statusCode).toBe(401);
    expect(agregar.statusCode).toBe(401);
    expect(quitar.statusCode).toBe(401);
  });

  it('rechaza un token inválido', async () => {
    const res = await request(app).get('/api/v1/favoritos').set('Authorization', 'Bearer token-falso');
    expect(res.statusCode).toBe(401);
  });

  it('al inicio la lista está vacía y lo informa', async () => {
    const res = await con(tokenA)(request(app).get('/api/v1/favoritos'));

    expect(res.statusCode).toBe(200);
    expect(res.body.favoritos).toEqual([]);
    expect(res.body.mensaje).toBe('Aún no tienes medicamentos favoritos');
  });

  it('Escenario 1: agrega un favorito y aparece en "Mis favoritos" con su precio', async () => {
    const id = await idDe('Panadol Forte');

    const agregar = await con(tokenA)(request(app).put(`/api/v1/favoritos/${id}`));
    expect(agregar.statusCode).toBe(201);
    expect(agregar.body.favorito).toBe(true);

    const lista = await con(tokenA)(request(app).get('/api/v1/favoritos'));
    expect(lista.body.favoritos).toHaveLength(1);
    expect(lista.body.favoritos[0].nombre).toBe('Panadol Forte');
    expect(lista.body.favoritos[0].precio_desde).toBe(12.9);
    expect(lista.body.favoritos[0].disponible).toBe(true);
  });

  it('el detalle muestra el corazón relleno (es_favorito) solo para quien lo guardó', async () => {
    const id = await idDe('Panadol Forte');

    const conSesion = await con(tokenA)(request(app).get(`/api/v1/medicamentos/${id}`));
    const otroCliente = await con(tokenB)(request(app).get(`/api/v1/medicamentos/${id}`));
    const invitado = await request(app).get(`/api/v1/medicamentos/${id}`);

    expect(conSesion.body.es_favorito).toBe(true);
    expect(otroCliente.body.es_favorito).toBe(false);
    expect(invitado.body.es_favorito).toBeNull();
  });

  it('agregar dos veces el mismo medicamento no lo duplica', async () => {
    const id = await idDe('Panadol Forte');

    const repetido = await con(tokenA)(request(app).put(`/api/v1/favoritos/${id}`));
    expect(repetido.statusCode).toBe(200);

    const lista = await con(tokenA)(request(app).get('/api/v1/favoritos'));
    expect(lista.body.favoritos).toHaveLength(1);
  });

  it('lista primero el favorito más reciente', async () => {
    const advil = await idDe('Advil');
    await con(tokenA)(request(app).put(`/api/v1/favoritos/${advil}`));

    const lista = await con(tokenA)(request(app).get('/api/v1/favoritos'));
    expect(lista.body.favoritos.map((f) => f.nombre)).toEqual(['Advil', 'Panadol Forte']);
  });

  it('cada cliente ve solo sus propios favoritos', async () => {
    const res = await con(tokenB)(request(app).get('/api/v1/favoritos'));

    expect(res.statusCode).toBe(200);
    expect(res.body.favoritos).toEqual([]);
  });

  it('Escenario 3: quitar de favoritos lo retira de la lista y apaga el corazón', async () => {
    const id = await idDe('Panadol Forte');

    const quitar = await con(tokenA)(request(app).delete(`/api/v1/favoritos/${id}`));
    expect(quitar.statusCode).toBe(200);
    expect(quitar.body.favorito).toBe(false);

    const lista = await con(tokenA)(request(app).get('/api/v1/favoritos'));
    expect(lista.body.favoritos.map((f) => f.nombre)).toEqual(['Advil']);

    const detalle = await con(tokenA)(request(app).get(`/api/v1/medicamentos/${id}`));
    expect(detalle.body.es_favorito).toBe(false);
  });

  it('quitar un medicamento que no era favorito no da error', async () => {
    const id = await idDe('Strepsils');
    const res = await con(tokenA)(request(app).delete(`/api/v1/favoritos/${id}`));
    expect(res.statusCode).toBe(200);
  });

  it('responde 404 al agregar un medicamento que no existe', async () => {
    const res = await con(tokenA)(request(app).put('/api/v1/favoritos/999999'));
    expect(res.statusCode).toBe(404);
  });

  it('responde 400 si el identificador no es numérico', async () => {
    const res = await con(tokenA)(request(app).put('/api/v1/favoritos/abc'));
    expect(res.statusCode).toBe(400);
  });
});
