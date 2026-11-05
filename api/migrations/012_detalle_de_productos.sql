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
