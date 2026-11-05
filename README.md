# FarmiQ

Plataforma de Gestión de Stock para Botica Elna (proyecto BuscaFarma).

## Estructura

- `api/`: API REST en Node.js + Express y migraciones SQL
- `mobile/`: app Flutter con dos interfaces: **cliente** y **personal de botica** (panel de stock)
- `db/`: base de datos completa en un solo script (`bash db/crear_base_de_datos.sh`)
- `web/`: reservado para un panel web futuro (el panel del personal hoy vive en la app)

## Requisitos

Docker Desktop (en Windows, con WSL2) y Git.

## Puesta en marcha

1. Crear los archivos de configuración:

        cp .env.example .env
        cp api/.env.example api/.env

   En `api/.env`, reemplazar `JWT_SECRET` por una clave propia (`openssl rand -hex 32`).

2. Levantar la base de datos y la API:

        docker compose up -d --build

3. Crear las tablas y los datos de prueba (elige una):

        docker compose exec api npm run migrar
        bash db/crear_base_de_datos.sh          # alternativa: todo en un solo script

4. Comprobar:

        curl http://localhost:3000/api/v1/health
        curl http://localhost:3000/api/v1/health/db

## Pruebas

Con los contenedores levantados y las migraciones aplicadas:

    docker compose exec api npm test

## Cuentas de prueba

| Rol | Correo | Contraseña |
|---|---|---|
| Cliente | `cliente.prueba@farmiq.test` | `Cliente123` |
| Personal (Botica Elna) | `personal.elna@farmiq.test` | `Personal123` |
| Personal (Botica Salud Total) | `personal.saludtotal@farmiq.test` | `Personal123` |
| Personal (Botica San Martín, Barranca) | `personal.barranca@farmiq.test` | `Personal123` |

Bórralas antes de pasar a producción.

## Funciones nuevas

- **Login de cliente como entrada principal**; el acceso del personal de botica está al pie, en letra discreta.
- **Bloqueo temporal**: 5 contraseñas incorrectas seguidas para un correo bloquean el acceso 15 minutos (aviso por correo y cuenta regresiva en la app). Restablecer la contraseña lo libera. Configurable con `LOGIN_MAX_INTENTOS` y `LOGIN_BLOQUEO_MINUTOS`.
- **Geolocalización**: pestaña Sedes con mapa, radio de búsqueda y stock por botica; el detalle de un medicamento muestra qué boticas cercanas lo tienen.
- **Reservas con plazo de pago**: al reservar, el stock queda *separado* 15 minutos (`RESERVA_MINUTOS`). Si no se paga, se libera solo (barrido cada 30 s + al consultar). El pago es **simulado** (`api/src/services/pago.service.js`): tarjeta que termina en `0000` o celular que termina en `000` se rechaza.
- **Panel del personal** (otra interfaz): resumen, inventario (stock y precio, HU27), alta de productos con ficha técnica y entrega de reservas con el código de retiro.
- **Catálogo ampliado** con ficha técnica por producto y 7 boticas de prueba.

## Comandos útiles

    docker compose logs -f api   # ver logs de la API
    docker compose down          # apagar (conserva los datos)
    docker compose down -v       # apagar y borrar la base de datos

## Flujo con Git

`main` es la versión estable y `develop` integra el trabajo. Cada historia de
usuario va en una rama `feature/huNN-descripcion` y entra a `develop` con un
Pull Request revisado por otro integrante.
