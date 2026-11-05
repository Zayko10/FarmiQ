-- =============================================================================
--  FarmiQ - Base de datos completa (PostgreSQL 16)
--  Equivale a ejecutar las migraciones 001 a 014 de api/migrations (en orden).
--
--  Crea: tablas, restricciones, índices, extensiones (unaccent, pgcrypto), el catálogo
--  ampliado con su ficha técnica, 7 boticas con inventario, las cuentas de prueba y deja
--  registradas todas las migraciones para que "npm run migrar" no las vuelva a aplicar.
--
--  Úsalo SOLO en una base vacía. Para ejecutarlo:  bash db/crear_base_de_datos.sh
--
--  CUENTAS DE PRUEBA (borrarlas antes de producción):
--    Cliente   cliente.prueba@farmiq.test         Cliente123
--    Personal  personal.elna@farmiq.test          Personal123  (Botica Elna)
--    Personal  personal.saludtotal@farmiq.test    Personal123  (Botica Salud Total)
--    Personal  personal.barranca@farmiq.test      Personal123  (Botica San Martín, Barranca)
--
--  OJO: medicamentos, precios, stock, dosis y boticas son DATOS DE PRUEBA, no reales.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE migraciones (
  nombre      TEXT PRIMARY KEY,
  aplicada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 001_boticas_y_usuarios.sql
-- ---------------------------------------------------------------------------
CREATE TABLE boticas (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre    TEXT NOT NULL,
  direccion TEXT NOT NULL,
  latitud   NUMERIC(9,6),
  longitud  NUMERIC(9,6),
  telefono  TEXT,
  activa    BOOLEAN NOT NULL DEFAULT true,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE usuarios (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre             TEXT NOT NULL,
  email              TEXT NOT NULL UNIQUE,
  telefono           TEXT,
  password_hash      TEXT NOT NULL,
  rol                TEXT NOT NULL DEFAULT 'cliente',
  botica_id          BIGINT REFERENCES boticas(id),
  acepto_terminos_en TIMESTAMPTZ NOT NULL,
  creado_en          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT usuarios_rol_valido CHECK (rol IN ('cliente', 'personal', 'admin')),
  CONSTRAINT usuarios_email_minuscula CHECK (email = lower(email)),
  CONSTRAINT usuarios_personal_con_botica CHECK (rol <> 'personal' OR botica_id IS NOT NULL)
);

INSERT INTO boticas (nombre, direccion)
VALUES ('Botica Elna', 'Chorrillos, Lima');

-- ---------------------------------------------------------------------------
-- 002_usuarios_direccion.sql
-- ---------------------------------------------------------------------------
ALTER TABLE usuarios ADD COLUMN direccion TEXT;

-- ---------------------------------------------------------------------------
-- 003_reset_passwords.sql
-- ---------------------------------------------------------------------------
CREATE TABLE password_resets (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id  BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token_hash  TEXT NOT NULL UNIQUE,
  expira_en   TIMESTAMPTZ NOT NULL,
  usado_en    TIMESTAMPTZ,
  creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX password_resets_usuario_idx ON password_resets (usuario_id);

-- ---------------------------------------------------------------------------
-- 004_ubicacion_botica_elna.sql
-- ---------------------------------------------------------------------------
UPDATE boticas
SET latitud = -12.197541,
    longitud = -76.974574
WHERE nombre = 'Botica Elna';

-- ---------------------------------------------------------------------------
-- 005_medicamentos_e_inventario.sql
-- ---------------------------------------------------------------------------
CREATE TABLE medicamentos (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre           TEXT NOT NULL,
  principio_activo TEXT NOT NULL,
  concentracion    TEXT NOT NULL,
  presentacion     TEXT NOT NULL,
  categoria        TEXT NOT NULL,
  es_generico      BOOLEAN NOT NULL DEFAULT false,
  requiere_receta  BOOLEAN NOT NULL DEFAULT false,
  prospecto_url    TEXT,
  activo           BOOLEAN NOT NULL DEFAULT true,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT medicamentos_unico UNIQUE (nombre, concentracion, presentacion)
);

CREATE INDEX medicamentos_principio_idx ON medicamentos (lower(principio_activo));
CREATE INDEX medicamentos_nombre_idx ON medicamentos (lower(nombre));

CREATE TABLE inventario (
  botica_id          BIGINT NOT NULL REFERENCES boticas(id) ON DELETE CASCADE,
  medicamento_id     BIGINT NOT NULL REFERENCES medicamentos(id) ON DELETE CASCADE,
  stock              INTEGER NOT NULL DEFAULT 0,
  precio             NUMERIC(8,2) NOT NULL,
  actualizado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (botica_id, medicamento_id),
  CONSTRAINT inventario_stock_no_negativo CHECK (stock >= 0),
  CONSTRAINT inventario_precio_no_negativo CHECK (precio >= 0)
);

CREATE INDEX inventario_medicamento_idx ON inventario (medicamento_id);

-- ---------------------------------------------------------------------------
-- 006_semilla_catalogo.sql
-- ---------------------------------------------------------------------------
-- HU15: dosis referencial para la ficha técnica
ALTER TABLE medicamentos ADD COLUMN dosis_referencial TEXT;

INSERT INTO medicamentos
  (nombre, principio_activo, concentracion, presentacion, categoria, es_generico, requiere_receta, dosis_referencial)
VALUES
  ('Panadol Forte',       'Paracetamol', '500 mg', 'Tabletas x 20', 'Dolor y fiebre', false, false, 'Adultos: 1 tableta cada 6 a 8 horas. Máximo 8 tabletas al día.'),
  ('Paracetamol Genfar',  'Paracetamol', '500 mg', 'Tabletas x 20', 'Dolor y fiebre', true,  false, 'Adultos: 1 tableta cada 6 a 8 horas. Máximo 8 tabletas al día.'),
  ('Paracetamol MK',      'Paracetamol', '500 mg', 'Tabletas x 20', 'Dolor y fiebre', true,  false, 'Adultos: 1 tableta cada 6 a 8 horas. Máximo 8 tabletas al día.'),
  ('Advil',               'Ibuprofeno',  '400 mg', 'Tabletas x 10', 'Dolor y fiebre', false, false, 'Adultos: 1 tableta cada 8 horas con alimentos. Máximo 3 al día.'),
  ('Ibuprofeno MK',       'Ibuprofeno',  '400 mg', 'Tabletas x 10', 'Dolor y fiebre', true,  false, 'Adultos: 1 tableta cada 8 horas con alimentos. Máximo 3 al día.'),
  ('Claritin',            'Loratadina',  '10 mg',  'Tabletas x 10', 'Alergias',       false, false, 'Adultos y niños mayores de 12 años: 1 tableta al día.'),
  ('Loratadina MK',       'Loratadina',  '10 mg',  'Tabletas x 10', 'Alergias',       true,  false, 'Adultos y niños mayores de 12 años: 1 tableta al día.'),
  ('Glucophage',          'Metformina',  '850 mg', 'Tabletas x 30', 'Diabetes',       false, true,  'Según indicación médica.'),
  ('Metformina MK',       'Metformina',  '850 mg', 'Tabletas x 30', 'Diabetes',       true,  true,  'Según indicación médica.'),
  ('Cozaar',              'Losartán',    '50 mg',  'Tabletas x 30', 'Presión arterial', false, true, 'Según indicación médica.'),
  ('Losartán MK',         'Losartán',    '50 mg',  'Tabletas x 30', 'Presión arterial', true,  true, 'Según indicación médica.'),
  ('Omeprazol MK',        'Omeprazol',   '20 mg',  'Cápsulas x 14', 'Digestivo',      true,  false, '1 cápsula al día en ayunas, según indicación médica.'),
  ('Strepsils',           'Amilmetacresol y alcohol diclorobencílico', '0.6 mg / 1.2 mg', 'Pastillas x 24', 'Garganta', false, false, 'Según las indicaciones del envase.');

-- Inventario de Botica Elna (algunos casos de prueba incluidos)
INSERT INTO inventario (botica_id, medicamento_id, stock, precio, actualizado_en)
SELECT b.id, m.id, v.stock, v.precio, now() - (v.horas_atras || ' hours')::interval
FROM (VALUES
  ('Panadol Forte',      25, 12.90,  1),
  ('Paracetamol Genfar', 40,  7.90,  1),
  ('Paracetamol MK',      0,  6.50,  2),
  ('Advil',              12, 14.50,  1),
  ('Ibuprofeno MK',      30,  5.00,  1),
  ('Claritin',            8, 18.00,  3),
  ('Loratadina MK',      20,  4.50,  3),
  ('Glucophage',          6, 24.00, 30),
  ('Metformina MK',      15,  9.50, 30),
  ('Cozaar',              4, 58.00,  2),
  ('Losartán MK',        18, 12.00,  2),
  ('Omeprazol MK',       22,  8.00,  5),
  ('Strepsils',          10, 16.50,  5)
) AS v(nombre, stock, precio, horas_atras)
JOIN medicamentos m ON m.nombre = v.nombre
JOIN boticas b ON b.nombre = 'Botica Elna';

-- ---------------------------------------------------------------------------
-- 007_busqueda_sin_tildes.sql
-- ---------------------------------------------------------------------------
-- HU03: buscar "losartan" debe encontrar "Losartán"
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ---------------------------------------------------------------------------
-- 008_caso_ficha_no_disponible.sql
-- ---------------------------------------------------------------------------
-- HU15 Escenario 2: caso de prueba de un medicamento sin ficha técnica cargada.
-- (El prospecto_url ya existe desde la migración 005 y lo cargará la botica desde el panel web, HU25.)
UPDATE medicamentos SET dosis_referencial = NULL WHERE nombre = 'Omeprazol MK';

-- ---------------------------------------------------------------------------
-- 009_favoritos.sql
-- ---------------------------------------------------------------------------
-- HU17: medicamentos favoritos del cliente
CREATE TABLE favoritos (
  usuario_id     BIGINT NOT NULL REFERENCES usuarios(id)     ON DELETE CASCADE,
  medicamento_id BIGINT NOT NULL REFERENCES medicamentos(id) ON DELETE CASCADE,
  creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (usuario_id, medicamento_id)
);

-- ---------------------------------------------------------------------------
-- 010_bloqueo_login.sql
-- ---------------------------------------------------------------------------
-- Bloqueo temporal del login: 5 contraseñas incorrectas seguidas para un mismo correo.
-- Se guarda por correo (exista o no la cuenta) para no revelar qué correos están registrados.
CREATE TABLE login_intentos (
  email           TEXT PRIMARY KEY,
  intentos        INTEGER NOT NULL DEFAULT 0,
  bloqueado_hasta TIMESTAMPTZ,
  ultimo_intento  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 011_reservas_y_stock_reservado.sql
-- ---------------------------------------------------------------------------
-- Reservas con pago dentro de 15 minutos.
-- stock           = unidades físicas en la botica.
-- stock_reservado = unidades "separadas" por reservas pendientes de pago.
-- Disponible para la venta = stock - stock_reservado.
ALTER TABLE inventario
  ADD COLUMN stock_reservado INTEGER NOT NULL DEFAULT 0,
  ADD CONSTRAINT inventario_reservado_valido
    CHECK (stock_reservado >= 0 AND stock_reservado <= stock);

CREATE TABLE reservas (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id      BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  botica_id       BIGINT NOT NULL REFERENCES boticas(id),
  medicamento_id  BIGINT NOT NULL REFERENCES medicamentos(id),
  cantidad        INTEGER NOT NULL,
  precio_unitario NUMERIC(8,2) NOT NULL,
  total           NUMERIC(10,2) NOT NULL,
  estado          TEXT NOT NULL DEFAULT 'pendiente_pago',
  codigo          TEXT NOT NULL UNIQUE,
  expira_en       TIMESTAMPTZ NOT NULL,
  metodo_pago     TEXT,
  pago_referencia TEXT,
  pagada_en       TIMESTAMPTZ,
  entregada_en    TIMESTAMPTZ,
  cancelada_en    TIMESTAMPTZ,
  creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT reservas_cantidad_valida CHECK (cantidad > 0),
  CONSTRAINT reservas_estado_valido CHECK (estado IN
    ('pendiente_pago', 'pagada', 'entregada', 'expirada', 'cancelada'))
);

CREATE INDEX reservas_usuario_idx ON reservas (usuario_id, creado_en DESC);
CREATE INDEX reservas_botica_idx  ON reservas (botica_id, estado);
-- Acelera el barrido de reservas vencidas
CREATE INDEX reservas_vencimiento_idx ON reservas (expira_en) WHERE estado = 'pendiente_pago';

-- ---------------------------------------------------------------------------
-- 012_detalle_de_productos.sql
-- ---------------------------------------------------------------------------
-- Información ampliada de cada producto (pantalla de detalle).
-- OJO: los textos son DATOS DE PRUEBA de carácter informativo; deben ser validados
-- por el químico farmacéutico de la botica antes de usarse con clientes reales.
ALTER TABLE medicamentos
  ADD COLUMN laboratorio        TEXT,
  ADD COLUMN descripcion        TEXT,
  ADD COLUMN indicaciones       TEXT,
  ADD COLUMN contraindicaciones TEXT,
  ADD COLUMN efectos_adversos   TEXT,
  ADD COLUMN conservacion       TEXT;

UPDATE medicamentos m SET
  descripcion        = d.descripcion,
  indicaciones       = d.indicaciones,
  contraindicaciones = d.contraindicaciones,
  efectos_adversos   = d.efectos_adversos,
  conservacion       = 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.'
FROM (VALUES
  ('Paracetamol',
   'Analgésico y antipirético de uso común.',
   'Alivio del dolor leve a moderado (cabeza, muscular, dental) y reducción de la fiebre.',
   'Alergia al paracetamol o enfermedad hepática grave. No combinar con otros productos que contengan paracetamol.',
   'Poco frecuentes: reacciones en la piel. Una sobredosis puede dañar el hígado.'),
  ('Ibuprofeno',
   'Antiinflamatorio no esteroideo (AINE) con acción analgésica y antipirética.',
   'Dolor leve a moderado, inflamación y fiebre.',
   'Úlcera gástrica activa, alergia a AINE o aspirina, insuficiencia renal, hepática o cardíaca grave y embarazo avanzado.',
   'Molestias gástricas, náuseas y mareos. Tomar con alimentos.'),
  ('Loratadina',
   'Antihistamínico de segunda generación que produce poca somnolencia.',
   'Rinitis alérgica, picazón, estornudos y urticaria.',
   'Alergia a la loratadina.',
   'Dolor de cabeza, somnolencia leve y boca seca.'),
  ('Metformina',
   'Antidiabético oral que reduce la glucosa en sangre.',
   'Diabetes mellitus tipo 2, siempre bajo control médico.',
   'Insuficiencia renal o hepática grave, cetoacidosis diabética y consumo excesivo de alcohol.',
   'Náuseas, diarrea, malestar abdominal y sabor metálico, sobre todo al inicio.'),
  ('Losartán',
   'Antihipertensivo del grupo de los antagonistas de los receptores de angiotensina II.',
   'Hipertensión arterial, siempre bajo control médico.',
   'Embarazo y alergia al losartán.',
   'Mareos, aumento de potasio en sangre y, rara vez, tos.'),
  ('Amilmetacresol y alcohol diclorobencílico',
   'Pastillas antisépticas para la garganta.',
   'Alivio de las molestias y el dolor al tragar causados por irritación de la garganta.',
   'Alergia a los componentes y niños menores de 6 años.',
   'Irritación local leve en la boca.')
) AS d(principio_activo, descripcion, indicaciones, contraindicaciones, efectos_adversos)
WHERE m.principio_activo = d.principio_activo
  AND m.nombre <> 'Omeprazol MK';  -- sin ficha a propósito (caso de prueba HU15)

UPDATE medicamentos SET laboratorio = 'Genfar' WHERE nombre = 'Paracetamol Genfar';
UPDATE medicamentos SET laboratorio = 'MK' WHERE nombre LIKE '% MK';

-- ---------------------------------------------------------------------------
-- 013_catalogo_ampliado.sql
-- ---------------------------------------------------------------------------
-- Catálogo ampliado (productos de boticas). DATOS DE PRUEBA: precios, stock, dosis y textos informativos
-- deben ser validados por el químico farmacéutico antes de uso real.
INSERT INTO medicamentos
  (nombre, principio_activo, concentracion, presentacion, categoria, es_generico, requiere_receta,
   dosis_referencial, descripcion, indicaciones, contraindicaciones, efectos_adversos, conservacion, laboratorio)
VALUES
  ('Aspirina', 'Ácido acetilsalicílico', '500 mg', 'Tabletas x 20', 'Dolor y fiebre', false, false, 'Adultos: 1 a 2 tabletas cada 6 a 8 horas, con alimentos. Máximo 8 tabletas al día.', 'Analgésico, antipirético y antiinflamatorio.', 'Dolor leve a moderado y fiebre.', 'Úlcera gástrica, hemorragias, alergia a AINE, embarazo y niños o adolescentes con fiebre por infección viral (riesgo de síndrome de Reye).', 'Molestias gástricas y mayor tendencia al sangrado.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Ácido Acetilsalicílico MK', 'Ácido acetilsalicílico', '500 mg', 'Tabletas x 20', 'Dolor y fiebre', true, false, 'Adultos: 1 a 2 tabletas cada 6 a 8 horas, con alimentos. Máximo 8 tabletas al día.', 'Analgésico, antipirético y antiinflamatorio.', 'Dolor leve a moderado y fiebre.', 'Úlcera gástrica, hemorragias, alergia a AINE, embarazo y niños o adolescentes con fiebre por infección viral (riesgo de síndrome de Reye).', 'Molestias gástricas y mayor tendencia al sangrado.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Voltaren Emulgel', 'Diclofenaco', '1 %', 'Gel x 30 g', 'Dolor muscular', false, false, 'Adultos: aplicar 2 a 4 g sobre la zona dolorida, 3 a 4 veces al día, con un suave masaje.', 'Gel antiinflamatorio de uso externo.', 'Dolor muscular y articular, torceduras y golpes sin herida.', 'Alergia a diclofenaco o AINE. No aplicar sobre heridas ni mucosas.', 'Enrojecimiento o picazón local.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Diclofenaco MK Gel', 'Diclofenaco', '1 %', 'Gel x 30 g', 'Dolor muscular', true, false, 'Adultos: aplicar 2 a 4 g sobre la zona dolorida, 3 a 4 veces al día, con un suave masaje.', 'Gel antiinflamatorio de uso externo.', 'Dolor muscular y articular, torceduras y golpes sin herida.', 'Alergia a diclofenaco o AINE. No aplicar sobre heridas ni mucosas.', 'Enrojecimiento o picazón local.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Zyrtec', 'Cetirizina', '10 mg', 'Tabletas x 10', 'Alergias', false, false, 'Adultos y niños mayores de 12 años: 1 tableta al día.', 'Antihistamínico de segunda generación.', 'Rinitis alérgica, picazón y urticaria.', 'Alergia a cetirizina o hidroxizina; insuficiencia renal grave.', 'Somnolencia, boca seca y dolor de cabeza.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Cetirizina MK', 'Cetirizina', '10 mg', 'Tabletas x 10', 'Alergias', true, false, 'Adultos y niños mayores de 12 años: 1 tableta al día.', 'Antihistamínico de segunda generación.', 'Rinitis alérgica, picazón y urticaria.', 'Alergia a cetirizina o hidroxizina; insuficiencia renal grave.', 'Somnolencia, boca seca y dolor de cabeza.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Buscapina', 'Hioscina butilbromuro', '10 mg', 'Grageas x 10', 'Digestivo', false, false, 'Adultos: 1 a 2 grageas, 3 veces al día.', 'Antiespasmódico que alivia los cólicos.', 'Cólicos y espasmos del estómago o del intestino.', 'Glaucoma de ángulo cerrado, retención urinaria, obstrucción intestinal y alergia al componente.', 'Boca seca, mareos y palpitaciones.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Hioscina MK', 'Hioscina butilbromuro', '10 mg', 'Grageas x 10', 'Digestivo', true, false, 'Adultos: 1 a 2 grageas, 3 veces al día.', 'Antiespasmódico que alivia los cólicos.', 'Cólicos y espasmos del estómago o del intestino.', 'Glaucoma de ángulo cerrado, retención urinaria, obstrucción intestinal y alergia al componente.', 'Boca seca, mareos y palpitaciones.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Imodium', 'Loperamida', '2 mg', 'Cápsulas x 12', 'Digestivo', false, false, 'Adultos: 2 cápsulas al inicio y 1 después de cada deposición líquida. Máximo 6 cápsulas al día sin indicación médica.', 'Antidiarreico que disminuye el movimiento del intestino.', 'Diarrea aguda sin fiebre ni sangre.', 'Niños menores de 6 años, diarrea con sangre o fiebre alta y obstrucción intestinal.', 'Estreñimiento, gases y mareos.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Loperamida MK', 'Loperamida', '2 mg', 'Cápsulas x 12', 'Digestivo', true, false, 'Adultos: 2 cápsulas al inicio y 1 después de cada deposición líquida. Máximo 6 cápsulas al día sin indicación médica.', 'Antidiarreico que disminuye el movimiento del intestino.', 'Diarrea aguda sin fiebre ni sangre.', 'Niños menores de 6 años, diarrea con sangre o fiebre alta y obstrucción intestinal.', 'Estreñimiento, gases y mareos.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Suero Oral MK', 'Sales de rehidratación oral', '1 sobre / litro', 'Sobre x 1', 'Digestivo', true, false, 'Disolver un sobre en 1 litro de agua hervida y enfriada. Beber a sorbos después de cada deposición líquida.', 'Sales para reponer agua y electrolitos en la diarrea.', 'Prevención y tratamiento de la deshidratación por diarrea o vómitos.', 'Vómitos incontrolables u obstrucción intestinal: acudir al médico.', 'Vómitos leves al inicio si se bebe muy rápido.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Simeticona MK', 'Simeticona', '80 mg', 'Tabletas masticables x 20', 'Digestivo', true, false, 'Adultos: 1 tableta masticable después de las comidas y al acostarse. Máximo 4 al día.', 'Antiflatulento.', 'Gases, distensión y pesadez abdominal.', 'Alergia al componente u obstrucción intestinal.', 'Muy bien tolerada; raramente malestar leve.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Ambroxol MK', 'Ambroxol', '30 mg / 5 mL', 'Jarabe x 120 mL', 'Tos y gripe', true, false, 'Adultos: 5 a 10 mL, 2 a 3 veces al día. Niños: según indicación del médico.', 'Mucolítico que facilita la expulsión de las flemas.', 'Tos con flema y bronquitis.', 'Alergia al ambroxol; úlcera gástrica activa.', 'Molestias gástricas y náuseas leves.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Redoxon', 'Vitamina C', '1 g', 'Tabletas efervescentes x 10', 'Vitaminas', false, false, 'Adultos: 1 tableta disuelta en un vaso de agua, 1 vez al día.', 'Suplemento de vitamina C.', 'Refuerzo de vitamina C en la dieta.', 'Cálculos renales de oxalato y alergia al componente.', 'Molestias gástricas con dosis altas.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Vitamina C MK', 'Vitamina C', '1 g', 'Tabletas efervescentes x 10', 'Vitaminas', true, false, 'Adultos: 1 tableta disuelta en un vaso de agua, 1 vez al día.', 'Suplemento de vitamina C.', 'Refuerzo de vitamina C en la dieta.', 'Cálculos renales de oxalato y alergia al componente.', 'Molestias gástricas con dosis altas.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Complejo B MK', 'Complejo B', 'B1, B6 y B12', 'Tabletas x 30', 'Vitaminas', true, false, 'Adultos: 1 tableta al día con alimentos, o según indicación del médico.', 'Suplemento de vitaminas del complejo B.', 'Apoyo nutricional cuando la dieta es insuficiente.', 'Alergia a los componentes. No exceder la dosis indicada.', 'Orina de color amarillo intenso (normal); molestias gástricas leves.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Calcio + Vitamina D3 MK', 'Carbonato de calcio y vitamina D3', '600 mg / 400 UI', 'Tabletas x 30', 'Vitaminas', true, false, 'Adultos: 1 tableta al día con alimentos.', 'Suplemento de calcio y vitamina D.', 'Apoyo para la salud de los huesos.', 'Exceso de calcio en sangre u orina y cálculos renales.', 'Estreñimiento y gases.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Isodine', 'Povidona yodada', '10 %', 'Solución x 120 mL', 'Primeros auxilios', false, false, 'Uso externo: aplicar sobre la piel limpia 1 a 3 veces al día.', 'Antiséptico de uso externo.', 'Desinfección de heridas pequeñas y de la piel.', 'Alergia al yodo, enfermedades de la tiroides y recién nacidos.', 'Irritación o enrojecimiento local.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Povidona Yodada MK', 'Povidona yodada', '10 %', 'Solución x 120 mL', 'Primeros auxilios', true, false, 'Uso externo: aplicar sobre la piel limpia 1 a 3 veces al día.', 'Antiséptico de uso externo.', 'Desinfección de heridas pequeñas y de la piel.', 'Alergia al yodo, enfermedades de la tiroides y recién nacidos.', 'Irritación o enrojecimiento local.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Alcohol Medicinal MK', 'Alcohol etílico', '70 %', 'Frasco x 250 mL', 'Primeros auxilios', true, false, 'Uso externo para desinfectar la piel intacta. No ingerir.', 'Desinfectante de uso externo.', 'Limpieza de la piel intacta y de superficies pequeñas.', 'No usar en heridas abiertas ni cerca de fuego: es inflamable.', 'Resequedad de la piel.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Amoxicilina MK', 'Amoxicilina', '500 mg', 'Cápsulas x 21', 'Antibióticos', true, true, 'Según indicación médica. Completar siempre el tratamiento.', 'Antibiótico del grupo de las penicilinas.', 'Infecciones bacterianas indicadas por el médico.', 'Alergia a las penicilinas.', 'Diarrea, náuseas y erupciones en la piel.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Azitromicina MK', 'Azitromicina', '500 mg', 'Tabletas x 3', 'Antibióticos', true, true, 'Según indicación médica. Completar siempre el tratamiento.', 'Antibiótico del grupo de los macrólidos.', 'Infecciones bacterianas indicadas por el médico.', 'Alergia a los macrólidos y enfermedad hepática grave.', 'Diarrea, náuseas y dolor abdominal.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Lipitor', 'Atorvastatina', '20 mg', 'Tabletas x 30', 'Colesterol', false, true, 'Según indicación médica.', 'Medicamento para reducir el colesterol.', 'Colesterol elevado, bajo control médico.', 'Embarazo, lactancia y enfermedad hepática activa.', 'Dolor muscular, molestias digestivas y dolor de cabeza.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', NULL),
  ('Atorvastatina MK', 'Atorvastatina', '20 mg', 'Tabletas x 30', 'Colesterol', true, true, 'Según indicación médica.', 'Medicamento para reducir el colesterol.', 'Colesterol elevado, bajo control médico.', 'Embarazo, lactancia y enfermedad hepática activa.', 'Dolor muscular, molestias digestivas y dolor de cabeza.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Amlodipino MK', 'Amlodipino', '5 mg', 'Tabletas x 30', 'Presión arterial', true, true, 'Según indicación médica.', 'Antihipertensivo del grupo de los bloqueadores de canales de calcio.', 'Hipertensión arterial, bajo control médico.', 'Shock, estenosis aórtica grave y alergia al componente.', 'Hinchazón de tobillos, enrojecimiento y dolor de cabeza.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Enalapril MK', 'Enalapril', '10 mg', 'Tabletas x 30', 'Presión arterial', true, true, 'Según indicación médica.', 'Antihipertensivo del grupo de los IECA.', 'Hipertensión arterial e insuficiencia cardíaca, bajo control médico.', 'Embarazo y antecedente de angioedema.', 'Tos seca, mareos y aumento de potasio.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK'),
  ('Salbutamol MK', 'Salbutamol', '100 mcg / dosis', 'Inhalador x 200 dosis', 'Respiratorio', true, true, 'Según indicación médica.', 'Broncodilatador de acción rápida.', 'Alivio de la falta de aire en asma y bronquitis.', 'Alergia al salbutamol.', 'Temblor, palpitaciones y nerviosismo.', 'Conservar en un lugar fresco y seco, a menos de 30 °C y fuera del alcance de los niños.', 'MK');

-- ---------------------------------------------------------------------------
-- 014_boticas_inventario_y_cuentas_de_prueba.sql
-- ---------------------------------------------------------------------------
-- Más boticas (datos de prueba, nombres inventados), su inventario y cuentas para probar.
-- Las cuentas de prueba usan contraseñas simples: BÓRRALAS antes de pasar a producción.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO boticas (nombre, direccion, latitud, longitud) VALUES
  ('Botica Salud Total', 'San Juan de Miraflores, Lima', -12.1585, -76.969),
  ('Farmacia Villa Salud', 'Villa El Salvador, Lima', -12.213, -76.933),
  ('Botica Santa Rosa', 'Chorrillos (Matellini), Lima', -12.195, -77.014),
  ('Farmacia Nueva Esperanza', 'Santiago de Surco (sur), Lima', -12.166, -76.99),
  ('Botica San Martín', 'Centro de Barranca (dato de prueba)', -10.75, -77.7667),
  ('Farmacia Salud y Vida', 'Barranca (dato de prueba)', -10.744, -77.76);

INSERT INTO inventario (botica_id, medicamento_id, stock, precio, actualizado_en)
SELECT b.id, m.id, v.stock, v.precio, now() - (v.horas || ' hours')::interval
FROM (VALUES
  ('Botica Elna', 'Aspirina', 0, 9.50, 3),
  ('Botica Elna', 'Ácido Acetilsalicílico MK', 5, 4.50, 1),
  ('Botica Elna', 'Voltaren Emulgel', 30, 22.00, 1),
  ('Botica Elna', 'Diclofenaco MK Gel', 0, 9.00, 1),
  ('Botica Elna', 'Zyrtec', 8, 19.50, 1),
  ('Botica Elna', 'Cetirizina MK', 30, 5.00, 6),
  ('Botica Elna', 'Buscapina', 40, 15.00, 3),
  ('Botica Elna', 'Hioscina MK', 0, 6.00, 2),
  ('Botica Elna', 'Imodium', 15, 17.00, 3),
  ('Botica Elna', 'Loperamida MK', 15, 4.50, 1),
  ('Botica Elna', 'Suero Oral MK', 3, 2.00, 3),
  ('Botica Elna', 'Simeticona MK', 40, 7.00, 3),
  ('Botica Elna', 'Ambroxol MK', 25, 8.50, 1),
  ('Botica Elna', 'Redoxon', 0, 21.00, 6),
  ('Botica Elna', 'Vitamina C MK', 12, 10.00, 3),
  ('Botica Elna', 'Complejo B MK', 3, 14.00, 1),
  ('Botica Elna', 'Calcio + Vitamina D3 MK', 12, 18.00, 1),
  ('Botica Elna', 'Isodine', 3, 16.00, 6),
  ('Botica Elna', 'Povidona Yodada MK', 15, 7.00, 2),
  ('Botica Elna', 'Alcohol Medicinal MK', 8, 5.50, 3),
  ('Botica Elna', 'Amoxicilina MK', 3, 24.00, 2),
  ('Botica Elna', 'Azitromicina MK', 8, 19.00, 2),
  ('Botica Elna', 'Lipitor', 12, 95.00, 2),
  ('Botica Elna', 'Atorvastatina MK', 0, 28.00, 2),
  ('Botica Elna', 'Amlodipino MK', 15, 14.00, 6),
  ('Botica Elna', 'Enalapril MK', 8, 10.00, 3),
  ('Botica Elna', 'Salbutamol MK', 25, 16.00, 6),
  ('Botica Salud Total', 'Ácido Acetilsalicílico MK', 4, 4.74, 30),
  ('Botica Salud Total', 'Voltaren Emulgel', 18, 23.87, 8),
  ('Botica Salud Total', 'Diclofenaco MK Gel', 0, 9.42, 8),
  ('Botica Salud Total', 'Zyrtec', 2, 20.43, 2),
  ('Botica Salud Total', 'Buscapina', 18, 16.05, 8),
  ('Botica Salud Total', 'Hioscina MK', 0, 6.50, 1),
  ('Botica Salud Total', 'Imodium', 35, 18.32, 4),
  ('Botica Salud Total', 'Loperamida MK', 25, 4.68, 4),
  ('Botica Salud Total', 'Ambroxol MK', 9, 9.20, 30),
  ('Botica Salud Total', 'Redoxon', 4, 22.41, 30),
  ('Botica Salud Total', 'Complejo B MK', 2, 15.21, 4),
  ('Botica Salud Total', 'Calcio + Vitamina D3 MK', 2, 18.80, 8),
  ('Botica Salud Total', 'Alcohol Medicinal MK', 25, 5.98, 2),
  ('Botica Salud Total', 'Amoxicilina MK', 18, 26.12, 30),
  ('Botica Salud Total', 'Lipitor', 18, 103.53, 4),
  ('Botica Salud Total', 'Atorvastatina MK', 2, 29.47, 1),
  ('Botica Salud Total', 'Amlodipino MK', 6, 14.97, 1),
  ('Botica Salud Total', 'Enalapril MK', 6, 10.43, 1),
  ('Botica Salud Total', 'Paracetamol Genfar', 25, 8.30, 2),
  ('Botica Salud Total', 'Advil', 25, 15.26, 8),
  ('Botica Salud Total', 'Loratadina MK', 18, 4.76, 8),
  ('Botica Salud Total', 'Glucophage', 2, 25.03, 4),
  ('Botica Salud Total', 'Cozaar', 35, 61.62, 8),
  ('Botica Salud Total', 'Losartán MK', 2, 12.75, 30),
  ('Botica Salud Total', 'Omeprazol MK', 35, 8.65, 1),
  ('Farmacia Villa Salud', 'Ácido Acetilsalicílico MK', 6, 4.96, 1),
  ('Farmacia Villa Salud', 'Voltaren Emulgel', 18, 23.61, 8),
  ('Farmacia Villa Salud', 'Diclofenaco MK Gel', 35, 9.84, 8),
  ('Farmacia Villa Salud', 'Zyrtec', 0, 21.23, 30),
  ('Farmacia Villa Salud', 'Cetirizina MK', 0, 5.45, 30),
  ('Farmacia Villa Salud', 'Hioscina MK', 35, 6.38, 2),
  ('Farmacia Villa Salud', 'Imodium', 6, 18.36, 30),
  ('Farmacia Villa Salud', 'Loperamida MK', 2, 4.86, 30),
  ('Farmacia Villa Salud', 'Suero Oral MK', 9, 2.14, 4),
  ('Farmacia Villa Salud', 'Simeticona MK', 9, 7.58, 1),
  ('Farmacia Villa Salud', 'Ambroxol MK', 2, 9.04, 2),
  ('Farmacia Villa Salud', 'Redoxon', 14, 23.18, 2),
  ('Farmacia Villa Salud', 'Vitamina C MK', 35, 10.95, 30),
  ('Farmacia Villa Salud', 'Isodine', 35, 17.20, 1),
  ('Farmacia Villa Salud', 'Alcohol Medicinal MK', 2, 6.03, 2),
  ('Farmacia Villa Salud', 'Amoxicilina MK', 14, 25.68, 4),
  ('Farmacia Villa Salud', 'Azitromicina MK', 0, 20.23, 8),
  ('Farmacia Villa Salud', 'Atorvastatina MK', 4, 30.57, 4),
  ('Farmacia Villa Salud', 'Amlodipino MK', 18, 15.23, 1),
  ('Farmacia Villa Salud', 'Enalapril MK', 4, 10.87, 4),
  ('Farmacia Villa Salud', 'Salbutamol MK', 4, 16.99, 4),
  ('Farmacia Villa Salud', 'Glucophage', 2, 25.86, 30),
  ('Farmacia Villa Salud', 'Cozaar', 4, 64.16, 2),
  ('Botica Santa Rosa', 'Ácido Acetilsalicílico MK', 14, 4.81, 8),
  ('Botica Santa Rosa', 'Cetirizina MK', 2, 5.25, 1),
  ('Botica Santa Rosa', 'Hioscina MK', 25, 6.28, 2),
  ('Botica Santa Rosa', 'Imodium', 18, 17.79, 1),
  ('Botica Santa Rosa', 'Suero Oral MK', 18, 2.13, 30),
  ('Botica Santa Rosa', 'Simeticona MK', 9, 7.27, 4),
  ('Botica Santa Rosa', 'Ambroxol MK', 14, 9.06, 4),
  ('Botica Santa Rosa', 'Redoxon', 0, 21.75, 30),
  ('Botica Santa Rosa', 'Vitamina C MK', 18, 10.30, 30),
  ('Botica Santa Rosa', 'Complejo B MK', 0, 14.94, 2),
  ('Botica Santa Rosa', 'Calcio + Vitamina D3 MK', 14, 19.10, 1),
  ('Botica Santa Rosa', 'Isodine', 9, 17.01, 4),
  ('Botica Santa Rosa', 'Povidona Yodada MK', 4, 7.28, 8),
  ('Botica Santa Rosa', 'Alcohol Medicinal MK', 9, 5.78, 1),
  ('Botica Santa Rosa', 'Amoxicilina MK', 14, 25.28, 8),
  ('Botica Santa Rosa', 'Azitromicina MK', 4, 20.20, 4),
  ('Botica Santa Rosa', 'Lipitor', 14, 98.29, 2),
  ('Botica Santa Rosa', 'Atorvastatina MK', 6, 29.05, 1),
  ('Botica Santa Rosa', 'Amlodipino MK', 2, 14.74, 30),
  ('Botica Santa Rosa', 'Enalapril MK', 25, 10.50, 2),
  ('Botica Santa Rosa', 'Salbutamol MK', 2, 17.10, 2),
  ('Botica Santa Rosa', 'Paracetamol Genfar', 0, 8.34, 1),
  ('Botica Santa Rosa', 'Advil', 2, 15.27, 8),
  ('Botica Santa Rosa', 'Ibuprofeno MK', 0, 5.30, 8),
  ('Botica Santa Rosa', 'Loratadina MK', 35, 4.73, 30),
  ('Botica Santa Rosa', 'Glucophage', 25, 25.26, 2),
  ('Botica Santa Rosa', 'Cozaar', 25, 61.56, 4),
  ('Botica Santa Rosa', 'Losartán MK', 6, 12.52, 4),
  ('Botica Santa Rosa', 'Strepsils', 18, 17.57, 2),
  ('Farmacia Nueva Esperanza', 'Aspirina', 35, 10.48, 1),
  ('Farmacia Nueva Esperanza', 'Ácido Acetilsalicílico MK', 0, 5.05, 30),
  ('Farmacia Nueva Esperanza', 'Voltaren Emulgel', 14, 24.09, 8),
  ('Farmacia Nueva Esperanza', 'Cetirizina MK', 35, 5.60, 2),
  ('Farmacia Nueva Esperanza', 'Buscapina', 25, 16.22, 4),
  ('Farmacia Nueva Esperanza', 'Hioscina MK', 4, 6.73, 2),
  ('Farmacia Nueva Esperanza', 'Loperamida MK', 0, 4.88, 8),
  ('Farmacia Nueva Esperanza', 'Suero Oral MK', 0, 2.19, 4),
  ('Farmacia Nueva Esperanza', 'Simeticona MK', 18, 7.66, 8),
  ('Farmacia Nueva Esperanza', 'Ambroxol MK', 0, 9.50, 1),
  ('Farmacia Nueva Esperanza', 'Vitamina C MK', 0, 11.18, 2),
  ('Farmacia Nueva Esperanza', 'Complejo B MK', 4, 15.29, 8),
  ('Farmacia Nueva Esperanza', 'Calcio + Vitamina D3 MK', 6, 19.86, 4),
  ('Farmacia Nueva Esperanza', 'Povidona Yodada MK', 2, 7.83, 2),
  ('Farmacia Nueva Esperanza', 'Amoxicilina MK', 9, 26.61, 8),
  ('Farmacia Nueva Esperanza', 'Azitromicina MK', 2, 21.08, 2),
  ('Farmacia Nueva Esperanza', 'Lipitor', 2, 106.38, 30),
  ('Farmacia Nueva Esperanza', 'Amlodipino MK', 14, 15.17, 4),
  ('Farmacia Nueva Esperanza', 'Enalapril MK', 25, 10.85, 4),
  ('Farmacia Nueva Esperanza', 'Salbutamol MK', 4, 17.63, 30),
  ('Farmacia Nueva Esperanza', 'Advil', 35, 16.22, 8),
  ('Farmacia Nueva Esperanza', 'Ibuprofeno MK', 9, 5.48, 2),
  ('Farmacia Nueva Esperanza', 'Glucophage', 6, 26.82, 30),
  ('Farmacia Nueva Esperanza', 'Metformina MK', 0, 10.49, 4),
  ('Farmacia Nueva Esperanza', 'Cozaar', 9, 63.63, 30),
  ('Farmacia Nueva Esperanza', 'Omeprazol MK', 6, 8.67, 8),
  ('Farmacia Nueva Esperanza', 'Strepsils', 25, 18.35, 8),
  ('Botica San Martín', 'Aspirina', 9, 10.56, 2),
  ('Botica San Martín', 'Ácido Acetilsalicílico MK', 25, 5.07, 4),
  ('Botica San Martín', 'Voltaren Emulgel', 14, 24.59, 8),
  ('Botica San Martín', 'Diclofenaco MK Gel', 2, 10.22, 4),
  ('Botica San Martín', 'Zyrtec', 4, 21.64, 8),
  ('Botica San Martín', 'Cetirizina MK', 35, 5.65, 1),
  ('Botica San Martín', 'Hioscina MK', 9, 6.60, 30),
  ('Botica San Martín', 'Imodium', 0, 19.17, 2),
  ('Botica San Martín', 'Loperamida MK', 2, 5.15, 30),
  ('Botica San Martín', 'Suero Oral MK', 14, 2.22, 1),
  ('Botica San Martín', 'Simeticona MK', 2, 7.99, 8),
  ('Botica San Martín', 'Ambroxol MK', 0, 9.41, 30),
  ('Botica San Martín', 'Vitamina C MK', 35, 11.38, 30),
  ('Botica San Martín', 'Complejo B MK', 35, 15.67, 8),
  ('Botica San Martín', 'Calcio + Vitamina D3 MK', 18, 20.07, 30),
  ('Botica San Martín', 'Isodine', 0, 17.68, 2),
  ('Botica San Martín', 'Povidona Yodada MK', 2, 7.75, 2),
  ('Botica San Martín', 'Alcohol Medicinal MK', 18, 6.17, 30),
  ('Botica San Martín', 'Amoxicilina MK', 9, 27.25, 8),
  ('Botica San Martín', 'Azitromicina MK', 9, 21.65, 30),
  ('Botica San Martín', 'Lipitor', 0, 106.52, 30),
  ('Botica San Martín', 'Atorvastatina MK', 9, 31.96, 1),
  ('Botica San Martín', 'Amlodipino MK', 9, 15.71, 8),
  ('Botica San Martín', 'Enalapril MK', 9, 11.25, 8),
  ('Botica San Martín', 'Salbutamol MK', 18, 18.19, 30),
  ('Botica San Martín', 'Paracetamol Genfar', 0, 9.08, 4),
  ('Botica San Martín', 'Advil', 4, 16.29, 8),
  ('Botica San Martín', 'Loratadina MK', 25, 5.17, 8),
  ('Botica San Martín', 'Glucophage', 2, 27.43, 4),
  ('Botica San Martín', 'Metformina MK', 18, 10.84, 30),
  ('Botica San Martín', 'Cozaar', 9, 64.74, 8),
  ('Botica San Martín', 'Strepsils', 25, 18.49, 2),
  ('Farmacia Salud y Vida', 'Aspirina', 25, 10.94, 1),
  ('Farmacia Salud y Vida', 'Ácido Acetilsalicílico MK', 9, 5.14, 8),
  ('Farmacia Salud y Vida', 'Voltaren Emulgel', 0, 25.31, 2),
  ('Farmacia Salud y Vida', 'Diclofenaco MK Gel', 0, 10.33, 1),
  ('Farmacia Salud y Vida', 'Zyrtec', 2, 22.29, 1),
  ('Farmacia Salud y Vida', 'Cetirizina MK', 9, 5.73, 4),
  ('Farmacia Salud y Vida', 'Buscapina', 25, 16.98, 30),
  ('Farmacia Salud y Vida', 'Hioscina MK', 35, 6.94, 2),
  ('Farmacia Salud y Vida', 'Loperamida MK', 18, 5.12, 30),
  ('Farmacia Salud y Vida', 'Suero Oral MK', 9, 2.32, 30),
  ('Farmacia Salud y Vida', 'Ambroxol MK', 35, 9.73, 4),
  ('Farmacia Salud y Vida', 'Redoxon', 25, 24.50, 2),
  ('Farmacia Salud y Vida', 'Complejo B MK', 18, 15.71, 8),
  ('Farmacia Salud y Vida', 'Calcio + Vitamina D3 MK', 18, 21.05, 2),
  ('Farmacia Salud y Vida', 'Isodine', 35, 18.69, 4),
  ('Farmacia Salud y Vida', 'Amoxicilina MK', 25, 26.90, 2),
  ('Farmacia Salud y Vida', 'Azitromicina MK', 4, 21.35, 4),
  ('Farmacia Salud y Vida', 'Lipitor', 2, 110.45, 30),
  ('Farmacia Salud y Vida', 'Atorvastatina MK', 25, 32.58, 1),
  ('Farmacia Salud y Vida', 'Amlodipino MK', 9, 16.38, 1),
  ('Farmacia Salud y Vida', 'Enalapril MK', 2, 11.42, 4),
  ('Farmacia Salud y Vida', 'Paracetamol Genfar', 9, 8.99, 8),
  ('Farmacia Salud y Vida', 'Advil', 4, 16.36, 1),
  ('Farmacia Salud y Vida', 'Ibuprofeno MK', 6, 5.72, 30),
  ('Farmacia Salud y Vida', 'Loratadina MK', 9, 5.14, 1),
  ('Farmacia Salud y Vida', 'Metformina MK', 35, 10.72, 8),
  ('Farmacia Salud y Vida', 'Omeprazol MK', 0, 9.24, 8)
) AS v(botica, medicamento, stock, precio, horas)
JOIN boticas b ON b.nombre = v.botica
JOIN medicamentos m ON m.nombre = v.medicamento;

-- Cuentas de prueba
--   Cliente:   cliente.prueba@farmiq.test        / Cliente123
--   Personal:  personal.elna@farmiq.test         / Personal123   (Botica Elna)
--              personal.saludtotal@farmiq.test   / Personal123   (Botica Salud Total)
--              personal.barranca@farmiq.test     / Personal123   (Botica San Martín, Barranca)
INSERT INTO usuarios (nombre, email, telefono, password_hash, rol, botica_id, acepto_terminos_en)
SELECT v.nombre, v.email, v.telefono, crypt(v.clave, gen_salt('bf', 10)), v.rol, b.id, now()
FROM (VALUES
  ('Cliente de Prueba',          'cliente.prueba@farmiq.test',      '900000001', 'Cliente123',  'cliente',  NULL),
  ('Personal Botica Elna',       'personal.elna@farmiq.test',       '900000002', 'Personal123', 'personal', 'Botica Elna'),
  ('Personal Botica Salud Total','personal.saludtotal@farmiq.test', '900000003', 'Personal123', 'personal', 'Botica Salud Total'),
  ('Personal Botica San Martín', 'personal.barranca@farmiq.test',   '900000004', 'Personal123', 'personal', 'Botica San Martín')
) AS v(nombre, email, telefono, clave, rol, botica)
LEFT JOIN boticas b ON b.nombre = v.botica;

-- Registro de migraciones aplicadas
INSERT INTO migraciones (nombre) VALUES
  ('001_boticas_y_usuarios.sql'),
  ('002_usuarios_direccion.sql'),
  ('003_reset_passwords.sql'),
  ('004_ubicacion_botica_elna.sql'),
  ('005_medicamentos_e_inventario.sql'),
  ('006_semilla_catalogo.sql'),
  ('007_busqueda_sin_tildes.sql'),
  ('008_caso_ficha_no_disponible.sql'),
  ('009_favoritos.sql'),
  ('010_bloqueo_login.sql'),
  ('011_reservas_y_stock_reservado.sql'),
  ('012_detalle_de_productos.sql'),
  ('013_catalogo_ampliado.sql'),
  ('014_boticas_inventario_y_cuentas_de_prueba.sql');

COMMIT;
