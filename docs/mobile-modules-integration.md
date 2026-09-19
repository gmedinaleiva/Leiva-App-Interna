# Integración Flutter de los módulos móviles

## Referencia verificada

- Repositorio backend: `sistemas-leivahnos/WSL-Capital-Inversiones`.
- Rama backend: `WSL-DEV`.
- Commit revisado: `ecba70155e6f89ed76bf50619a6148702f3e1856`.
- Dominio Stage: `https://monitor.leivahnos.com.ar/api/app/v1`.
- Rama Flutter: `DEV`.

El 19/09/2026 las rutas de vehículos, dársenas y Mis Gastos respondieron `401`
sin sesión y validación TLS correcta. Esto confirma que están desplegadas y que
no permiten lectura anónima.

## Funciones integradas

| Módulo | Funciones del cliente Flutter |
|---|---|
| Salas | Listado, detalle, disponibilidad, alta idempotente, cancelación y dársenas para visitantes externos. |
| Vehículos | En curso, próximos e historial; disponibilidad, solicitud, inicio, finalización, cancelación, extensión, telemetría, trayectoria y multas propias. |
| Estacionamiento | Solicitudes propias, plano lógico por sucursal, alta idempotente y cancelación. |
| Mis Gastos | Tablero, rendiciones, comprobantes, alertas, rubros, carga multipart, detalle, archivo, reenvío y evidencia de combustible. |

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

## Notificaciones

Existe una interfaz `PushRepository` sin implementación. No se generan tokens
ni se incluye configuración Firebase hasta recibir el proyecto corporativo,
los identificadores definitivos y el backend de registro de dispositivos.

## Observación sobre el OpenAPI recibido

El archivo `0.3.0-pilot` entregado como referencia termina antes de la sección
`components`; por eso contiene referencias `$ref` sin definición y omite los
cuerpos completos de algunas operaciones. La implementación Flutter se validó
contra los esquemas Pydantic y routers publicados en el commit indicado. No se
incorporó el OpenAPI incompleto al repositorio como contrato ejecutable.
