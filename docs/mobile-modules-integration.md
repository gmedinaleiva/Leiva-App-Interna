# Integración Flutter de los módulos móviles

## Referencia verificada

- Repositorio backend: `sistemas-leivahnos/WSL-Capital-Inversiones`.
- Rama backend: `WSL-DEV`.
- Commit funcional revisado: `619e3f8`.
- Contrato revisado: `0.5.0-pilot`, publicado mediante la rama documental
  `AGENTS`.
- Dominio Stage: `https://monitor.leivahnos.com.ar/api/app/v1`.
- Rama Flutter: `DEV`.

El 19/09/2026 las rutas de vehículos, dársenas y Mis Gastos respondieron `401`
sin sesión y validación TLS correcta. Esto confirma que están desplegadas y que
no permiten lectura anónima.

## Funciones integradas

| Módulo | Funciones del cliente Flutter |
|---|---|
| Salas | Listado, detalle, disponibilidad, alta idempotente, cancelación y dársenas para visitantes externos. |
| Vehículos | En curso, próximos e historial; disponibilidad, solicitud con distancia, ocupantes y equipaje; dársena de regreso al crear o posteriormente; inicio, finalización, cancelación, extensión, telemetría, trayectoria, panel de combustible y detalle de multas/evidencia propia. |
| Estacionamiento | Solicitudes propias, plano lógico por sucursal, alta idempotente y cancelación. |
| Mis Gastos | Tablero, rendiciones, adelantos, carga y edición de comprobantes, preview local de imágenes/PDF, envío y corrección de períodos, confirmación de acreditaciones, reenvío y evidencia de combustible. |

Cada acceso se muestra únicamente cuando `/auth/me` devuelve la capacidad
correspondiente. Las comprobaciones de interfaz no reemplazan la autorización
del backend.

## Seguridad del cliente

- La cookie de sesión y el CSRF continúan en almacenamiento seguro.
- Todas las mutaciones usan el interceptor CSRF existente.
- Las altas de salas, vehículos, dársenas y comprobantes generan UUID v4 y
  conservan la misma clave durante los reintentos del formulario.
- Las fechas se envían en UTC con zona horaria explícita.
- El selector de comprobantes admite PDF, JPG y PNG, con un límite preventivo
  de 15 MB en el cliente. El archivo se envía al portal y no se conserva en la
  aplicación.
- Los previews se recuperan mediante la sesión segura y se renderizan desde
  memoria; no se crean archivos públicos ni enlaces reutilizables.
- El cliente no envía identificadores de usuario, empleado, rol ni permisos.
- Un `401` elimina inmediatamente cookie, CSRF e identidad local. Un `403`
  fuerza una nueva lectura de `/auth/me` para retirar capacidades revocadas.
- Flutter Web muestra solamente que el piloto está disponible en la app móvil;
  no inicia autenticación ni llamadas a la API.

## Viajes y telemetría

El viaje activo consulta `/live` cada 45 segundos únicamente mientras su
pantalla está visible y la aplicación permanece en primer plano. El historial
usa `/trajectory` sin refrescar GeoSat. La UI etiqueta los cálculos de velocidad
y cinemómetros como estimaciones preventivas y separa las multas confirmadas.

La reserva representa `return_parking`, incluidos estado y notas de
resolución. Una extensión vuelve a consultar el detalle para reflejar si la
dársena pasó a `requiere_revision`. Las cargas de combustible se presentan
como inferencias de GeoSat Extras hasta su conciliación; nunca como cargas
confirmadas por la app.

## Notificaciones

Existe una interfaz `PushRepository` sin implementación. No se generan tokens
ni se incluye configuración Firebase hasta recibir el proyecto corporativo,
los identificadores definitivos y el backend de registro de dispositivos.

## Estado de validación de Vehículos

El cliente se implementó contra OpenAPI `0.5.0-pilot` y se contrastó con los
routers y esquemas publicados por el anfitrión. `flutter analyze`, las pruebas
Flutter y la compilación Android pasan. Las rutas de detalle, trayectoria,
aviso y dársena de regreso rechazan el acceso sin sesión con `401`.

La persistencia y los casos autenticados `403`, `404`, `409`, `422` e
idempotencia quedan pendientes de evidencia con `demo_sistemas_flota`; hasta
entonces el módulo no se marca como terminado.
