# Integración Flutter de los módulos móviles

## Referencia verificada

- Repositorio backend: `sistemas-leivahnos/WSL-Capital-Inversiones`.
- Rama backend: `WSL-DEV`.
- Commit revisado: `7c961d677bc7de41b769aed728006aa1f8f63c77`.
- Dominio Stage: `https://monitor.leivahnos.com.ar/api/app/v1`.
- Rama Flutter: `DEV`.

El 19/09/2026 las rutas de vehículos, dársenas y Mis Gastos respondieron `401`
sin sesión y validación TLS correcta. Esto confirma que están desplegadas y que
no permiten lectura anónima.

## Funciones integradas

| Módulo | Funciones del cliente Flutter |
|---|---|
| Salas | Listado, disponibilidad, alta idempotente y cancelación. |
| Vehículos | Listado propio, disponibilidad, solicitud idempotente, inicio, finalización y cancelación. |
| Estacionamiento | Solicitudes propias, disponibilidad por sucursal, alta idempotente y cancelación. |
| Mis Gastos | Tablero, rendiciones, comprobantes, alertas, rubros y carga multipart de PDF o imagen. |

Cada acceso se muestra únicamente cuando `/auth/me` devuelve la capacidad
correspondiente. Las comprobaciones de interfaz no reemplazan la autorización
del backend.

## Seguridad del cliente

- La cookie de sesión y el CSRF continúan en almacenamiento seguro.
- Todas las mutaciones usan el interceptor CSRF existente.
- Las altas de salas, vehículos, dársenas y comprobantes generan claves de
  idempotencia aleatorias de 256 bits.
- Las fechas se envían en UTC con zona horaria explícita.
- El selector de comprobantes admite PDF, JPG y PNG, con un límite preventivo
  de 15 MB en el cliente. El archivo se envía al portal y no se conserva en la
  aplicación.
- El cliente no envía identificadores de usuario, empleado, rol ni permisos.

## Observación sobre el OpenAPI recibido

El archivo `0.3.0-pilot` entregado como referencia termina antes de la sección
`components`; por eso contiene referencias `$ref` sin definición y omite los
cuerpos completos de algunas operaciones. La implementación Flutter se validó
contra los esquemas Pydantic y routers publicados en el commit indicado. No se
incorporó el OpenAPI incompleto al repositorio como contrato ejecutable.
