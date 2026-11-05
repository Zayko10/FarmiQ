#!/usr/bin/env bash
# FarmiQ - Crea la base de datos completa a partir de db/farmiq_base_de_datos.sql
#
# Uso (desde cualquier carpeta del proyecto):
#   bash db/crear_base_de_datos.sh            crea la base (solo si está vacía)
#   bash db/crear_base_de_datos.sh --reset    BORRA todo y la crea de nuevo
#
# Requiere Docker encendido y el archivo .env de la raíz del proyecto.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL="$RAIZ/db/farmiq_base_de_datos.sql"
cd "$RAIZ"

if [ ! -f .env ]; then
  echo "ERROR: no existe el archivo .env en $RAIZ (cópialo de .env.example)."
  exit 1
fi
if [ ! -f "$SQL" ]; then
  echo "ERROR: no se encuentra $SQL"
  exit 1
fi

# Lee POSTGRES_USER y POSTGRES_DB del .env (ignora los saltos de línea de Windows)
set -a
# shellcheck disable=SC1090
source <(tr -d '\r' < .env)
set +a

psql_db() { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"; }

echo "==> Encendiendo la base de datos..."
docker compose up -d db

echo "==> Esperando a que PostgreSQL esté listo..."
for _ in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    LISTA=1
    break
  fi
  sleep 2
done
if [ -z "${LISTA:-}" ]; then
  echo "ERROR: PostgreSQL no respondió. Revisa: docker compose logs db"
  exit 1
fi

EXISTE="$(psql_db -tA -c "SELECT to_regclass('public.medicamentos') IS NOT NULL;" | tr -d '[:space:]')"

if [ "$EXISTE" = "t" ]; then
  if [ "${1:-}" != "--reset" ]; then
    echo
    echo "La base de datos '$POSTGRES_DB' YA tiene tablas. No se hizo ningún cambio."
    echo "Si quieres borrarla y crearla de nuevo, ejecuta:"
    echo "    bash db/crear_base_de_datos.sh --reset"
    exit 0
  fi
  echo
  echo "ATENCIÓN: se va a BORRAR todo el contenido de la base '$POSTGRES_DB'."
  read -r -p "Escribe SI para continuar: " RESPUESTA
  if [ "$RESPUESTA" != "SI" ]; then
    echo "Cancelado. No se cambió nada."
    exit 0
  fi
  echo "==> Borrando el contenido actual..."
  psql_db -q -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
fi

echo "==> Creando tablas y datos de ejemplo..."
psql_db -q < "$SQL"

echo
echo "==> Listo. Contenido de la base de datos:"
psql_db -c "SELECT (SELECT count(*) FROM boticas)      AS boticas,
                   (SELECT count(*) FROM usuarios)     AS usuarios,
                   (SELECT count(*) FROM medicamentos) AS medicamentos,
                   (SELECT count(*) FROM inventario)   AS inventario,
                   (SELECT count(*) FROM favoritos)    AS favoritos,
                   (SELECT count(*) FROM reservas)     AS reservas,
                   (SELECT count(*) FROM migraciones)  AS migraciones;"
echo
echo "Cuentas de prueba:"
echo "  Cliente   cliente.prueba@farmiq.test        Cliente123"
echo "  Personal  personal.elna@farmiq.test         Personal123"
echo "  Personal  personal.saludtotal@farmiq.test   Personal123"
echo "  Personal  personal.barranca@farmiq.test     Personal123"
