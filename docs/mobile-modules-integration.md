# Integración Flutter de los módulos móviles

## Referencia verificada

- Repositorio backend: `sistemas-leivahnos/WSL-Capital-Inversiones`.
- Rama backend: `WSL-DEV`.
- Commit funcional revisado: `2a35bb5`.
- Contrato revisado: `0.6.0-pilot`, publicado mediante la rama documental
  `AGENTS`.
- Dominio Stage: `https://monitor.leivahnos.com.ar/api/app/v1`.
- Rama Flutter: `DEV`.

El 19/09/2026 las rutas de vehículos, dársenas y Mis Gastos respondieron `401`
sin sesión y validación TLS correcta. Esto confirma que están desplegadas y que
no permiten lectura anónima.

## Funciones integradas

| Módulo | Funciones del cliente Flutter |
|---|---|
| Salas | Listado, detalle, disponibilidad, alta idempotente, participantes internos y externos, edición, retiro/cancelación y dársenas para visitantes externos. |
| Vehículos | En curso, próximos e historial; disponibilidad, solicitud con distancia, ocupantes y equipaje; dársena de regreso al crear o posteriormente; inicio, finalización, cancelación, extensión, telemetría, trayectoria, panel de combustible y detalle de multas/evidencia propia. |
| Estacionamiento | Solicitudes propias, plano lógico por sucursal, alta idempotente, cancelación y trazabilidad de solicitudes vinculadas a salas o viajes. |
| Mis Gastos | Tablero, rendiciones, adelantos, carga y edición de comprobantes, referencia de ticket, vínculo opcional con viaje propio, preview local de imágenes/PDF, envío y corrección de períodos, confirmación de acreditaciones, reenvío, evidencia de combustible, multas personales y reporte PDF compartible. |

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

## Alcance de perfiles

La app es una herramienta de autogestión para empleados. No incorpora ABM ni
operaciones administrativas de Flota, Guardia, Recepción, Tesorería,
Presidencia o Sistemas.

En una etapa posterior podrá admitir usuarios gerentes únicamente para
autorizar o rechazar solicitudes. Cada autorización deberá llegar mediante una
capacidad móvil explícita de `/auth/me`, una ruta publicada en `/api/app/v1` y
auditoría del portal. Hasta que exista ese contrato, Flutter no mostrará ni
inferirá acciones gerenciales.

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

Desde OpenAPI `0.8.0-pilot`, el usuario puede consentir que el teléfono continúe
recibiendo avisos después del logout ordinario o del vencimiento de la cookie.
Flutter conserva en Android Keystore una credencial opaca exclusiva del
dispositivo. Las llamadas `Device` no envían cookie ni CSRF y sólo consultan el
estado mínimo, renuevan el token FCM o desvinculan esa instalación.

Sin sesión, el portal reemplaza título y cuerpo por un aviso genérico. Al tocar
la notificación, Flutter conserva el deep link permitido, solicita login y
recién después consulta el recurso autenticado. `logout-all`, reset de
contraseña, usuario desactivado y baja móvil revocan el enrolamiento. La
credencial vence a los 90 días y se rota durante un login posterior.

Salas, estados administrativos de vehículos y dársenas ya producen eventos.
Gastos y avisos GeoSat de velocidad/radar tienen categoría y contrato, pero sus
emisores todavía están pendientes en el portal y no se presentan como
garantizados.

El cliente Android implementa el contrato APP-011: consulta `/push/status`,
mantiene un identificador aleatorio por instalación en almacenamiento seguro,
registra o rota el token con `PUT /push/installations/{installation_id}` y lo
revoca antes del logout cuando no existe consentimiento persistente. Con
consentimiento conserva el enrolamiento mediante las rutas `push/device`.
Permite configurar las seis categorías publicadas.

El canal Android es `leiva_general`. Los avisos recibidos en primer plano se
muestran mediante una notificación local; segundo plano y aplicación terminada
usan FCM. Sólo se aceptan `leivaapp://home`, reservas numéricas de vehículos y
solicitudes numéricas de estacionamiento. Al abrirlas siempre se consulta de
nuevo la API autenticada.

La integración permanece cerrada mientras falte
`android/app/google-services.json` o `/push/status` informe que el proveedor no
está configurado. En ese estado no solicita permiso, no obtiene tokens y no
simula entregas. El archivo de cuenta de servicio de Firebase pertenece
exclusivamente al servidor y nunca debe copiarse al proyecto Flutter.

## Cámara e ingreso local

- La carga de comprobantes permite tomar una fotografía con la cámara o elegir
  un PDF/imagen existente. La fotografía se comprime a un máximo de 2048 px y
  calidad 82 antes de enviarse, mantiene el límite de 15 MB y muestra una vista
  previa. El archivo temporal no se conserva como documento público.
- El usuario puede recordarse en el almacenamiento seguro del dispositivo. La
  contraseña nunca se guarda.
- La huella desbloquea únicamente una sesión opaca todavía válida en el portal.
  Si la sesión venció o fue revocada, se exige nuevamente la contraseña.

## Ubicación del teléfono

El anfitrión determinó que la app no debe capturar ni transmitir la ubicación
del teléfono. La ubicación funcional corresponde al vehículo y continúa
obteniéndose de GeoSat mediante `/vehicle-reservations/{id}/live` y
`/vehicle-reservations/{id}/trajectory`. Android no declara permisos de
ubicación ni ejecuta servicios de rastreo en segundo plano.

## Estado de validación de Push Android

El cliente `1.8.0+8001` compila e inicia sin `google-services.json`, mostrando
el estado diferido informado por el portal. `flutter analyze` y las 20 pruebas
Flutter pasan. Las rutas `GET /push/status`, `PUT /push/installations/{id}` y
`DELETE /push/installations/{id}` rechazan solicitudes anónimas con `401`.

La entrega real fue validada el 21/09/2026 en un Moto G34: FCM aceptó el envío
con la aplicación terminada. `google-services.json` está instalado localmente e
ignorado por Git; la cuenta de servicio requerida por el backend no forma parte
del APK ni del repositorio Flutter.

## Estado de validación de Vehículos

El cliente se implementó contra OpenAPI `0.5.0-pilot` y se contrastó con los
routers y esquemas publicados por el anfitrión. `flutter analyze`, las pruebas
Flutter y la compilación Android pasan. Las rutas de detalle, trayectoria,
aviso y dársena de regreso rechazan el acceso sin sesión con `401`.

La persistencia y los casos autenticados `403`, `404`, `409`, `422` e
idempotencia quedan pendientes de evidencia con `demo_sistemas_flota`; hasta
entonces el módulo no se marca como terminado.

## Estado de validación de Salas, Estacionamiento y Mis Gastos

El cliente se implementó contra OpenAPI `0.5.0-pilot`. El análisis estático y
las 14 pruebas Flutter pasan. Sin sesión, la búsqueda de participantes, la
edición y el retiro de una sala, y la descarga del reporte PDF responden `401`
en Stage.

La verificación autenticada debe realizarse desde Android con el usuario piloto
y comprobar cada alta y cambio también en el portal web. Los resultados `403`,
`404`, `409`, `422`, la repetición idempotente y la persistencia cruzada quedan
pendientes de esa prueba; por eso estos módulos aún no se marcan como
terminados.
