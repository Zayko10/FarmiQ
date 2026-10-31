# FarmiQ

Plataforma de Gestión de Stock para Botica Elna (proyecto BuscaFarma).

## Estructura

- `api/`: API REST en Node.js + Express y migraciones SQL
- `mobile/`: app del cliente (Flutter), pendiente
- `web/`: panel web de la botica (React), pendiente

## Requisitos

Docker Desktop (en Windows, con WSL2) y Git.

## Puesta en marcha

1. Crear los archivos de configuración:

        cp .env.example .env
        cp api/.env.example api/.env

   En `api/.env`, reemplazar `JWT_SECRET` por una clave propia (`openssl rand -hex 32`).

2. Levantar la base de datos y la API:

        docker compose up -d --build

3. Crear las tablas:

        docker compose exec api npm run migrar

4. Comprobar:

        curl http://localhost:3000/api/v1/health
        curl http://localhost:3000/api/v1/health/db

## Pruebas

Con los contenedores levantados y las migraciones aplicadas:

    docker compose exec api npm test

## Comandos útiles

    docker compose logs -f api   # ver logs de la API
    docker compose down          # apagar (conserva los datos)
    docker compose down -v       # apagar y borrar la base de datos

## Flujo con Git

`main` es la versión estable y `develop` integra el trabajo. Cada historia de
usuario va en una rama `feature/huNN-descripcion` y entra a `develop` con un
Pull Request revisado por otro integrante.
