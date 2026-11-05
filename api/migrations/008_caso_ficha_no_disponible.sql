-- HU15 Escenario 2: caso de prueba de un medicamento sin ficha técnica cargada.
-- (El prospecto_url ya existe desde la migración 005 y lo cargará la botica desde el panel web, HU25.)
UPDATE medicamentos SET dosis_referencial = NULL WHERE nombre = 'Omeprazol MK';
