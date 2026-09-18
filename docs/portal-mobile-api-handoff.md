# Traspaso a Capital Inversiones: API segura para Leiva App Interna

## Mensaje para entregar al otro Codex

Implementá en Capital Inversiones Stage una API JSON versionada para que la aplicación Flutter Leiva App Interna pueda autenticar usuarios y operar exclusivamente estos módulos de autogestión:

1. Reservas propias de vehículos.
2. Reservas de salas.
3. Solicitudes propias de dársenas de estacionamiento.
4. Mis Gastos: consulta, carga de comprobantes, edición de borradores, reenvío y envío de rendiciones propias.

Trabajá en `sistemas-leivahnos/WSL-Capital-Inversiones`, rama `WSL-DEV`, partiendo de `origin/WSL-DEV`. La referencia verificada al redactar este pedido es `da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd`; ejecutá `git fetch origin --prune` y registrá el hash real usado antes de modificar.

No expongas directamente las rutas HTML `/internal/*` ni agregues accesos administrativos a la app. Creá `/api/app/v1` y reutilizá servicios, validaciones, permisos, transacciones y auditoría existentes. El servidor debe derivar siempre el usuario, empleado, departamento y alcance desde la sesión autenticada. Nunca debe confiar en un `user_id`, `employee_id`, rol o permiso enviado por Flutter.

Aplicá íntegramente los requisitos de este documento. Si una regla funcional no puede inferirse con certeza, conservá el comportamiento actual del portal y documentá la decisión. No leas, copies, publiques ni registres valores de `.env`, credenciales, tokens, datos productivos o archivos locales sin seguimiento.

Antes de considerar el trabajo terminado, entregá migraciones, pruebas automatizadas funcionales y de autorización, OpenAPI de la nueva API, variables de entorno documentadas sin secretos, ejemplos sanitizados y un informe de despliegue. No despliegues a producción ni cambies `TEST`/`PROD` sin instrucción explícita.

## Estado del portal relevado

La revisión se realizó sobre `WSL-DEV` en `da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd`.

| Circuito | Implementación actual que debe reutilizarse |
|---|---|
| Login y permisos | `app/services/auth_service.py`, `app/security.py`, `app/dependencies.py`, `build_session_user()` |
| Vehículos | `app/routers/geosat.py`, `GeoSatAccessPolicy`, `GeoSatReservationService`, `GeoSatParkingCoordinator` |
| Salas | `app/routers/meeting_rooms.py`, `MeetingRoomReservationService`, `MeetingRoomNotificationService`, `ParkingMeetingRoomCoordinator` |
| Dársenas | `app/routers/parking.py`, `ParkingReservationService` |
| Mis Gastos | `app/routers/my_expenses.py`, `SupplierWorkflowService`, almacenamiento y validaciones de comprobantes, integración Paperless/ARCA existente |

Las rutas actuales mezclan HTML, formularios, redirecciones y algunas respuestas JSON. La API nueva debe llamar a una capa de servicios común; no debe simular formularios internos ni duplicar reglas de negocio dentro de los routers.

En el commit revisado no se encontró una protección CSRF general, una política CORS explícita ni rate limiting para el login. Esto impide considerar seguras para una app las rutas existentes tal como están. La nueva API debe incorporar esos controles antes de habilitarse fuera del entorno Stage.

## Arquitectura requerida

Crear una estructura equivalente a:

```text
app/
  api/app_v1/
    router.py
    auth.py
    dependencies.py
    schemas.py
    vehicles.py
    rooms.py
    parking.py
    expenses.py
    errors.py
  models/api_session.py
  services/api_session_service.py
  services/api_audit_service.py
alembic/versions/<revision>_add_api_sessions.py
```

Registrar un único router con prefijo `/api/app/v1`. Mantener separado el contrato JSON de los routers web. Extraer lógica compartida a servicios cuando hoy sólo exista dentro de una función de ruta.

Todas las fechas de la API deben usar ISO 8601 con zona horaria. Aceptar offsets explícitos y responder en UTC con sufijo `Z`; la interfaz podrá mostrarlos en `America/Argentina/Buenos_Aires`. No aceptar fechas ambiguas sin zona.

## Autenticación recomendada

Para esta primera integración usar sesiones opacas almacenadas en el servidor. No implementar JWT casero ni reutilizar como API la cookie firmada que hoy contiene el usuario completo.

### Tabla de sesiones

Agregar una tabla `api_sessions` con, como mínimo:

- `id` UUID interno.
- `user_id` con clave foránea.
- `token_hash`, único; almacenar HMAC-SHA-256 del token usando un secreto exclusivo de sesiones API.
- `csrf_token_hash`.
- `device_name` saneado y limitado.
- `client_platform`: `android` o `web`, sólo informativo.
- `created_at`, `last_seen_at`, `idle_expires_at`, `absolute_expires_at`.
- `revoked_at`, `revoked_reason`.
- `created_ip_hash`, `last_ip_hash` y `user_agent_hash`; no guardar más datos de red de los necesarios.

Generar el identificador con un CSPRNG de al menos 256 bits. Rotarlo al autenticar y al elevar privilegios. Guardar únicamente su hash autenticado. La cookie debe ser:

```http
Set-Cookie: __Host-leiva_app_session=<token>; Path=/; Secure; HttpOnly; SameSite=Strict
```

No definir `Domain` para una cookie con prefijo `__Host-`. Usar una duración inactiva corta —por ejemplo 30 minutos— y una duración absoluta configurable —por ejemplo 12 horas—. La política definitiva debe quedar en variables de entorno. Cerrar y revocar todas las sesiones cuando el usuario se desactive; al cambiar la contraseña, revocar las demás sesiones del usuario.

Android debe conservar la cookie exclusivamente en almacenamiento seguro respaldado por Android Keystore. Flutter web debe dejarla bajo control del navegador; JavaScript nunca debe leerla. No guardar credenciales, cookies ni tokens en `SharedPreferences`, `localStorage`, logs o analítica.

### Endpoints de sesión

| Método y ruta | Comportamiento |
|---|---|
| `POST /api/app/v1/auth/login` | JSON con `username`, `password`, `device_name`, `client_platform`; valida con `authenticate_user()`, crea sesión nueva, devuelve usuario, capacidades y token CSRF. |
| `GET /api/app/v1/auth/me` | Devuelve identidad mínima, permisos efectivos y capacidades de módulos. Renueva sólo la expiración inactiva dentro del límite absoluto. |
| `POST /api/app/v1/auth/logout` | Requiere CSRF, revoca la sesión en servidor y expira la cookie. Debe ser idempotente. |
| `POST /api/app/v1/auth/logout-all` | Requiere contraseña actual o reautenticación; revoca todas las sesiones del usuario. |

La respuesta ante usuario inexistente, inactivo o contraseña incorrecta debe ser el mismo `401 invalid_credentials`, con texto genérico y tiempo de respuesta comparable. Registrar el resultado sin contraseña. Limitar intentos por combinación de usuario normalizado y dirección/origen: sugerencia inicial de 5 intentos por 15 minutos y demora progresiva, configurable y compartida entre instancias mediante Redis o almacenamiento central. No aplicar bloqueos permanentes que permitan denegación de servicio contra otra persona.

En cada solicitud, cargar el usuario activo y sus permisos actuales desde base de datos, o desde un caché de muy corta duración invalidado por versión. No confiar en una copia de permisos guardada al iniciar sesión.

## CSRF, CORS y transporte

- Emitir un token CSRF aleatorio ligado a la sesión. Devolverlo en login y permitir renovarlo con `GET /api/app/v1/auth/csrf`.
- Exigir `X-CSRF-Token` válido en todo `POST`, `PUT`, `PATCH` y `DELETE`, incluso desde Android. No aceptar mutaciones mediante `GET`.
- Aceptar sólo `Content-Type: application/json` o los `multipart/form-data` documentados. Rechazar formularios simples en la API para reducir ataques CSRF.
- Configurar CORS con una lista exacta de orígenes de Flutter web por entorno, `allow_credentials=true`, métodos y cabeceras mínimas. No usar `*`, reflexión del encabezado `Origin` ni expresiones amplias de subdominios.
- Android no necesita CORS; CORS tampoco reemplaza autenticación, autorización ni CSRF.
- Publicar la API únicamente por HTTPS. Habilitar HSTS en el proxy una vez verificados todos los subdominios afectados.
- Rechazar `Host` y `X-Forwarded-*` no confiables. Configurar proxies confiables explícitamente.

## Contrato transversal

Respuesta correcta:

```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "server_time": "2026-09-18T18:20:04Z"
  }
}
```

Respuesta de error:

```json
{
  "error": {
    "code": "reservation_conflict",
    "message": "El recurso ya no está disponible para ese horario.",
    "fields": {}
  },
  "meta": {
    "request_id": "uuid"
  }
}
```

Usar códigos HTTP coherentes: `400` formato inválido, `401` sin sesión, `403` sin permiso general, `404` recurso inexistente o ajeno, `409` conflicto de disponibilidad/estado/idempotencia, `413` archivo grande, `415` tipo no permitido, `422` validación de campos y `429` límite excedido. No devolver trazas, SQL, rutas internas, secretos ni excepciones crudas.

Todas las mutaciones de creación deben aceptar `Idempotency-Key`, asociada al usuario, método y ruta durante al menos 24 horas. Una repetición equivalente devuelve el resultado original; reutilizar la clave con otro cuerpo devuelve `409`.

## Capacidades devueltas por el servidor

`GET /auth/me` debe responder capacidades explícitas calculadas en el servidor:

```json
{
  "user": {
    "id": 123,
    "username": "usuario",
    "full_name": "Nombre Apellido"
  },
  "capabilities": {
    "vehicle_reservations": {"view": true, "create": true},
    "room_reservations": {"view": true, "create": true},
    "parking_requests": {"view": true, "create": true},
    "my_expenses": {"benefits": true, "travel": false, "upload": true}
  }
}
```

La app oculta módulos según estas capacidades, pero el backend debe volver a autorizarlos en cada endpoint.

## API de reservas de vehículos

Reutilizar `GeoSatAccessPolicy.current_employee()`, los permisos activos `GeoSatVehicleEmployeePermission`, `GeoSatReservationService` y `GeoSatParkingCoordinator`.

| Método y ruta | Alcance |
|---|---|
| `GET /vehicles/availability?from=&to=` | Sólo vehículos activos y habilitados para el empleado autenticado, disponibles en la ventana solicitada. |
| `GET /vehicle-reservations?status=&from=&to=&cursor=` | Sólo reservas del empleado autenticado; paginación por cursor. |
| `GET /vehicle-reservations/{id}` | Sólo propia. Excluir datos operativos, credenciales GeoSat y telemetría no necesaria. |
| `POST /vehicle-reservations` | Crea solicitud propia con `vehicle_id`, `reserved_from`, `reserved_to`, propósito, destino, distancia, ocupantes, equipaje y dársena de regreso opcional. |
| `POST /vehicle-reservations/{id}/extend` | Sólo propia y en estado permitido; reutiliza `extend_active()`. |
| `POST /vehicle-reservations/{id}/actions` | Lista cerrada de acciones de autogestión permitidas por el servicio actual. No aceptar nombres de métodos arbitrarios. |
| `POST /vehicle-reservations/{id}/return-parking` | Solicita dársena de regreso mediante `GeoSatParkingCoordinator`. |

No exponer sincronización GeoSat, cuentas, usuarios remotos, posiciones de terceros, mantenimiento, multas, administración de flota ni endpoints bajo `/accounts`. La trayectoria o posición sólo podrá agregarse posteriormente con una decisión de privacidad específica; queda fuera de esta entrega.

## API de reservas de salas

Reutilizar `MeetingRoomReservationService`, las notificaciones y la coordinación opcional de estacionamiento.

| Método y ruta | Alcance |
|---|---|
| `GET /branches` | Sucursales activas con campos mínimos. Puede compartirse con los demás módulos. |
| `GET /rooms?branch_id=` | Salas activas, capacidad y equipamiento público interno. |
| `GET /rooms/availability?branch_id=&from=&to=&capacity=` | Disponibilidad sin nombres ni detalles de reservas ajenas. |
| `GET /room-reservations?from=&to=&cursor=` | Reservas donde el usuario es organizador, responsable o participante interno. |
| `GET /room-reservations/{id}` | Sólo si participa, es responsable/organizador o tiene el permiso administrativo ya existente. |
| `POST /room-reservations` | Crea con `room_id`, fechas, título, notas, participantes internos/externos y coordinación opcional de parking. |
| `PATCH /room-reservations/{id}` | Sólo organizador/responsable o gestor habilitado; conserva reglas de conflicto y notificaciones. |
| `POST /room-reservations/{id}/cancel` | Cancela con motivo y cancela estacionamiento vinculado. |
| `POST /room-reservations/{id}/withdraw` | Permite a un participante retirarse sin alterar otros participantes. |

Limitar título, notas, nombres, organización y correo. Normalizar correos y no permitir contenido HTML. La búsqueda de participantes internos debe ofrecer un endpoint acotado que devuelva únicamente `id`, nombre y correo institucional, requiera texto mínimo y tenga rate limiting; no descargar el directorio completo.

## API de dársenas de estacionamiento

Reutilizar `ParkingReservationService`. Esta API es de autogestión; la aprobación de Recepción/Guardia permanece en el portal.

| Método y ruta | Alcance |
|---|---|
| `GET /parking/availability?branch_id=&from=&to=&vehicle_type=` | Sólo dársenas activas `compartida` disponibles. No revelar quién ocupa las demás. |
| `GET /parking/requests?status=&cursor=` | Sólo solicitudes cuyo `requested_by_user_id` coincide con el usuario autenticado. |
| `GET /parking/requests/{id}` | Sólo propia; responder `404` para una ajena. |
| `POST /parking/requests` | Crea una solicitud propia con dársena, fechas, tipo, patente, propósito y notas. |
| `POST /parking/requests/{id}/cancel` | Sólo propia y en estado `pendiente` o `aprobada`. |

No exponer en esta API la creación de dársenas, bloqueos, indicadores, agenda general ni acciones de aprobación/ingreso/egreso.

## API de Mis Gastos

Reutilizar `resolve_personal_expense_profile()`, `_personal_expense_document_for_user()`, las validaciones de períodos/rubros, duplicados, combustible, ARCA, Paperless, almacenamiento y `SupplierWorkflowService`. Extraer esas funciones a servicios públicos probables en vez de importar helpers privados desde el nuevo router.

| Método y ruta | Alcance |
|---|---|
| `GET /expenses/bootstrap` | Perfil laboral mínimo, campos faltantes, capacidades, rubros permitidos, períodos propios abiertos y opciones propias necesarias. |
| `GET /expenses?type=&status=&period_id=&cursor=` | Sólo documentos del empleado autenticado. |
| `GET /expenses/{id}` | Sólo propio, usando una verificación equivalente a `_personal_expense_document_for_user()`. |
| `GET /expenses/{id}/file` | Archivo propio, con autorización en cada descarga y cabeceras seguras. No exponer ruta, token Paperless ni identificadores internos innecesarios. |
| `POST /expenses/review` | `multipart/form-data`; valida campos, hash, duplicados y archivo antes de confirmar. |
| `POST /expenses` | Crea gasto propio tras revisión, reutilizando todas las reglas actuales. |
| `PATCH /expenses/{id}` | Sólo borrador u observado propio y período editable. |
| `POST /expenses/{id}/resubmit` | Sólo observado propio. |
| `GET /expense-periods` | Sólo períodos del empleado autenticado. |
| `POST /expense-periods/{id}/submit` | Envía únicamente un período propio en estado permitido. |

Las decisiones de Gerencia/Presidencia, correcciones administrativas y confirmaciones de tesorería quedan fuera del alcance móvil inicial.

### Archivos

- Permitir inicialmente PDF, JPEG y PNG; agregar otros formatos sólo con necesidad comprobada.
- Máximo configurable sugerido: 10 MiB por archivo y límites de cantidad por solicitud.
- Validar extensión, `Content-Type` y firma real del archivo. Rechazar discrepancias, HTML, SVG, ejecutables, archivos comprimidos y contenido con rutas.
- Generar nombres internos aleatorios, sanear el nombre original y almacenar fuera de cualquier raíz pública.
- Mantener el hash SHA-256 y la detección de duplicados ya existente.
- Pasar por antivirus o cola de cuarentena antes de marcar el comprobante disponible para procesos posteriores.
- Servir descargas con `Content-Disposition: attachment`, tipo controlado, `X-Content-Type-Options: nosniff` y `Cache-Control: private, no-store`.
- Nunca registrar contenido, nombres sensibles completos, rutas internas ni tokens de Paperless.

## Autorización y aislamiento de datos

Reglas obligatorias:

1. Comprobar sesión activa y usuario activo en todas las rutas.
2. Resolver el legajo/empleado desde el usuario autenticado.
3. Revalidar permiso y propiedad en cada operación y cada archivo.
4. Para recursos ajenos, devolver `404` cuando no sea necesario revelar su existencia.
5. Aplicar filtros de propiedad en la consulta SQL, no después de traer colecciones generales a memoria.
6. Seleccionar sólo columnas necesarias. No serializar modelos SQLAlchemy completos.
7. Prohibir mass assignment; usar esquemas Pydantic separados para entrada y salida con `extra="forbid"`.
8. No aceptar rol, estado final, aprobador, propietario, `user_id` o `employee_id` desde el cliente.
9. Toda transición debe pasar por el servicio de dominio y su lista cerrada de estados/acciones.
10. Cambiar permisos o desactivar un usuario debe surtir efecto sin esperar a que venza la sesión.

## Integridad y concurrencia

Las comprobaciones de disponibilidad seguidas de un `INSERT` pueden sufrir carreras. Para salas, vehículos y dársenas, ejecutar validación y escritura en una sola transacción y bloquear la fila del recurso con `SELECT ... FOR UPDATE` antes de volver a comprobar superposiciones. Evaluar una restricción PostgreSQL de exclusión por rango como defensa adicional, compatible con los estados que bloquean cada servicio.

No confiar en la disponibilidad mostrada previamente por la app. Un conflicto al confirmar debe devolver `409 reservation_conflict` y, si el servicio lo calcula, una próxima franja sugerida.

## Validación de entradas

- Límites máximos explícitos para cada texto; recortar sólo cuando el comportamiento actual lo requiera y preferir `422` ante pérdida de datos.
- Fechas dentro de un horizonte configurable; fin estrictamente posterior al inicio y duración máxima por módulo.
- Cantidades positivas con `Decimal`, moneda dentro de lista permitida y sin flotantes para importes.
- Patentes, correos y nombres con normalización y longitud acotada.
- Paginación por cursor con máximo de 100 registros; valor por defecto 25.
- Ordenamientos y filtros mediante enumeraciones cerradas; nunca interpolar campos recibidos en SQL.
- Límite de cuerpo JSON, cantidad de parámetros y tiempo de solicitud en proxy y aplicación.

## Auditoría, privacidad y observabilidad

Registrar para cada mutación: `request_id`, usuario, sesión, acción, tipo/id de recurso, resultado, código y timestamp. Para cambios de estado, guardar estado anterior y posterior. Sanear saltos de línea y caracteres de control para evitar inyección de logs.

No registrar contraseñas, cookies, CSRF, cuerpos completos, comprobantes, notas personales, ubicación, cabeceras `Authorization` ni datos bancarios. Los eventos de login deben distinguir éxito, credencial inválida, rate limit y sesión revocada sin permitir enumeración desde la respuesta.

Agregar métricas de errores `401/403/409/429`, intentos de login, sesiones activas y latencia por endpoint. Definir alertas por picos anormales sin incluir datos personales en etiquetas.

## Cabeceras y exposición

- `Cache-Control: no-store` para autenticación y respuestas con datos personales.
- `X-Content-Type-Options: nosniff`.
- `Referrer-Policy: no-referrer` para la API.
- Política CSP estricta para Flutter web desde el proxy; no es una cabecera útil para respuestas JSON por sí sola.
- Deshabilitar o autenticar `/docs`, `/redoc` y el esquema OpenAPI en producción. Conservar el archivo OpenAPI como artefacto interno versionado.
- No exponer endpoints de administración, métricas, debug ni health detallado a Internet.
- Restringir Stage por VPN/red corporativa mientras se valida. Si la API debe ser pública para Android fuera de la red, publicar sólo `/api/app/v1`, detrás de WAF/proxy y rate limiting; mantener `/internal`, administración y observabilidad bajo controles de red actuales.

## Variables de entorno

Documentar sin valores reales:

```dotenv
APP_API_ENABLED=false
APP_API_SESSION_HMAC_KEY=
APP_API_IDLE_TIMEOUT_SECONDS=1800
APP_API_ABSOLUTE_TIMEOUT_SECONDS=43200
APP_API_ALLOWED_ORIGINS=https://<flutter-web-stage>
APP_API_LOGIN_LIMIT=5
APP_API_LOGIN_WINDOW_SECONDS=900
APP_API_MAX_JSON_BYTES=131072
APP_API_MAX_UPLOAD_BYTES=10485760
APP_API_TRUSTED_PROXY_CIDRS=
APP_API_DOCS_ENABLED=false
```

El servicio debe negarse a arrancar en Stage/producción si falta la clave de sesión, es débil o conserva un valor de ejemplo. La clave debe venir del gestor de secretos y ser independiente de `SECRET_KEY` y de claves usadas por otras integraciones.

## Pruebas obligatorias

### Autenticación

- Login correcto, contraseña incorrecta, usuario inexistente e inactivo.
- Mensaje genérico y comportamiento comparable para credenciales inválidas.
- Rate limiting distribuido.
- Cookie con `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/` y sin `Domain`.
- Expiración inactiva/absoluta, logout, logout-all, revocación y rotación.
- CSRF faltante, inválido, de otra sesión y correcto.
- CORS permite sólo orígenes exactos y no entrega credenciales a otros.

### Autorización e IDOR

- Usuario A no puede leer, descargar, editar, cancelar ni reenviar recursos del usuario B cambiando IDs.
- Empleado sin legajo o permiso recibe la respuesta prevista.
- Permiso revocado durante una sesión se aplica en la siguiente solicitud.
- La app nunca habilita endpoints administrativos mediante parámetros manipulados.

### Negocio y concurrencia

- Dos solicitudes simultáneas para el mismo recurso y horario producen una sola reserva.
- Reintentos con igual `Idempotency-Key` no duplican reservas ni gastos.
- Fechas, estados y transiciones inválidas fallan sin escrituras parciales.
- Notificaciones y coordinación entre sala/dársena o vehículo/dársena mantienen consistencia si ocurre un error.

### Archivos

- Tamaño excedido, MIME falso, firma inválida, archivo duplicado, nombre malicioso y archivo de otro usuario.
- Descarga con autorización por objeto y cabeceras correctas.
- Los logs no contienen contenido ni secretos.

Ejecutar además análisis de dependencias, SAST y pruebas DAST autenticadas contra Stage. Alinear la revisión con OWASP ASVS y MASVS para autenticación, almacenamiento y transporte. Una revisión externa o prueba de penetración es necesaria antes de una publicación por Internet; ninguna implementación debe describirse como invulnerable.

## Criterios de aceptación

El trabajo se considera listo para integrar cuando:

1. La API está bajo `/api/app/v1` y las rutas HTML continúan funcionando.
2. La app puede iniciar y cerrar sesión sin almacenar la contraseña.
3. `/auth/me` devuelve capacidades calculadas y no permisos confiados al cliente.
4. Los cuatro módulos operan sólo sobre datos permitidos para el usuario.
5. CSRF, CORS, rate limiting, sesión revocable, auditoría e idempotencia tienen pruebas.
6. Las reservas concurrentes no se superponen.
7. Los archivos pasan validación, autorización y cuarentena.
8. OpenAPI y ejemplos no contienen datos reales.
9. No se publicaron secretos ni archivos locales sin seguimiento.
10. El informe final incluye commit, migración, pruebas ejecutadas, riesgos residuales y pasos exactos para habilitar Stage con `APP_API_ENABLED=true`.

## Referencias de seguridad

- [OWASP REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)
