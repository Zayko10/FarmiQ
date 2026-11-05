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
