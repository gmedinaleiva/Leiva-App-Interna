# Plan de integración del piloto seguro de autenticación

## Objetivo del primer corte

Reemplazar el acceso simulado de Leiva App Interna por autenticación real contra la API JSON de Capital Inversiones, exclusivamente en Android y contra Stage.

Este corte valida:

- credenciales del portal;
- sesión opaca mediante cookie segura;
- recuperación de la sesión al abrir la app;
- token CSRF ligado a la sesión;
- cierre de la sesión actual y cierre de todas las sesiones;
- revocación, expiración y usuario deshabilitado;
- tratamiento seguro de errores y límites de intentos.

Este corte no habilita reservas, gastos, administración ni Flutter web. Aunque la API devuelva capacidades, todas deben permanecer deshabilitadas hasta que cada módulo tenga endpoints y pruebas de autorización.

## Estado y condición de entrada

Información recibida del portal:

- Base utilizada: `da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd`.
- Commit funcional informado: `ce22652`.
- GLPI: Proyecto `#40`, Tarea `#243`, Ticket `#1052`, Seguimiento `#1869`.

Al momento de redactar este plan, `origin/WSL-DEV` todavía apunta a `da5ccd7` y GitHub no contiene el objeto `ce22652`. Por lo tanto, la primera condición es publicar el commit funcional en `WSL-DEV`.

No se debe habilitar la API ni escribir el cliente definitivo basándose únicamente en el resumen recibido. Primero hay que revisar el código y el OpenAPI publicados.

## Fase 0 — Publicación y revisión del contrato

Responsable: Capital Inversiones.

1. Publicar `ce22652` —o su commit sucesor— en `origin/WSL-DEV`.
2. Confirmar que el commit publicado desciende de `da5ccd7` sin reescritura del historial.
3. Entregar la migración de `api_sessions` y las pruebas del piloto.
4. Entregar el OpenAPI interno y ejemplos sin datos reales para:
   - `POST /api/app/v1/auth/login`;
   - `GET /api/app/v1/auth/me`;
   - `GET /api/app/v1/auth/csrf`;
   - `POST /api/app/v1/auth/logout`;
   - `POST /api/app/v1/auth/logout-all`.
5. Confirmar exactamente:
   - cuerpo de cada solicitud;
   - estructura de respuestas y errores;
   - nombre real de la cookie;
   - cabecera CSRF;
   - comportamiento de renovación por actividad;
   - códigos para sesión vencida, revocada y rate limiting;
   - si `logout-all` exige nuevamente la contraseña;
   - política de `Origin` para clientes nativos sin cabecera `Origin`.
6. Revisar que ningún endpoint de autenticación redirija a HTML. La API debe responder JSON también ante errores.

Criterio de salida: el commit es accesible desde GitHub, el contrato está versionado y las pruebas del portal pasan.

## Fase 1 — Preparación controlada de Stage

Responsable: Capital Inversiones/infraestructura.

1. Aplicar la migración en Stage y verificar su reversión antes de habilitar el flag.
2. Generar `APP_API_SESSION_HMAC_KEY` en el gestor de secretos con un CSPRNG. No enviarla por chat ni guardarla en un archivo del repositorio.
3. Configurar un único usuario piloto inicialmente:

   ```dotenv
   APP_API_ENABLED=true
   APP_API_AUTH_PROVIDER=local_stage
   APP_API_SESSION_HMAC_KEY=<gestor-de-secretos>
   APP_API_TEST_USERNAMES=<usuario-piloto>
   ```

4. Verificar que una lista vacía no autorice usuarios y que un usuario fuera de la lista reciba el mismo error genérico que una credencial inválida.
5. Publicar sólo `/api/app/v1/auth/*` en el proxy de Stage. Mantener `/internal`, administración y observabilidad bajo sus controles actuales.
6. Verificar el certificado TLS desde un dispositivo Android real y desde el emulador. No instalar validadores permisivos, no aceptar certificados inválidos y no desactivar la verificación TLS.
7. Definir límites de cuerpo pequeños para autenticación, timeouts y limitación adicional en el proxy sin reemplazar el control compartido en PostgreSQL.
8. Comprobar las banderas de la cookie desde una respuesta real: `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, sin `Domain`.
9. Confirmar que Stage se niega a iniciar con proveedor `local_stage` si `APP_ENV` es producción o si la clave es débil.

Plan de reversión: establecer `APP_API_ENABLED=false`, reiniciar el servicio y revocar las sesiones piloto. La aplicación Flutter debe volver a mostrar “servicio no disponible” sin perder estabilidad.

Criterio de salida: los cinco endpoints funcionan por HTTPS para un único usuario piloto y permanecen cerrados para el resto.

## Fase 2 — Cliente de autenticación en Flutter

Responsable: Leiva App Interna, rama `DEV`.

### Estructura propuesta

```text
lib/
  app/
    leiva_app.dart
  core/
    config/app_config.dart
    network/api_client.dart
    network/api_error.dart
    security/secure_session_store.dart
  features/auth/
    data/auth_api.dart
    data/auth_repository.dart
    domain/auth_session.dart
    domain/auth_user.dart
    domain/app_capabilities.dart
    presentation/auth_controller.dart
    presentation/login_screen.dart
  features/home/
    presentation/home_screen.dart
```

La demo actual está concentrada en `lib/main.dart`. Antes de conectar la red se separará por responsabilidad sin cambiar la apariencia aprobada.

### Configuración

- Recibir la URL por compilación, por ejemplo `--dart-define=APP_API_BASE_URL=https://<host>/api/app/v1`.
- Fallar al iniciar una compilación Stage/producción si falta la URL, no usa `https` o el host no coincide con la lista permitida de esa variante.
- No incluir usuarios, contraseñas, cookies, claves HMAC ni secretos en `dart-define`, recursos, APK, repositorio o logs.
- Agregar el permiso Android `INTERNET` en el manifiesto principal para builds release.
- No incorporar una excepción de tráfico HTTP ni un `badCertificateCallback`.

### Transporte de sesión

- Usar un cliente HTTP único y testeable.
- Aceptar y persistir únicamente la cookie de sesión esperada para el host configurado.
- Guardar la cookie en almacenamiento cifrado respaldado por Android Keystore. No usar `SharedPreferences` ni archivos de cookies en texto plano.
- Mantener el token CSRF en almacenamiento seguro asociado a esa sesión.
- Agregar `X-CSRF-Token` sólo a las mutaciones dirigidas al mismo host.
- Rechazar redirecciones de API hacia otro host y no reenviar cookies o cabeceras CSRF en una redirección.
- No registrar cuerpos de login, `Set-Cookie`, `Cookie`, CSRF ni valores del almacenamiento seguro.
- Usar timeouts finitos y convertir errores de transporte en estados comprensibles sin mostrar detalles internos.

Las dependencias concretas se seleccionarán después de revisar compatibilidad con Flutter estable. Si se usa un gestor de cookies de terceros, su persistencia deberá reemplazarse o envolverse para que la cookie termine en Android Keystore.

### Estado de autenticación

El controlador tendrá estados explícitos:

```text
checkingSession
unauthenticated
submittingCredentials
authenticated
rateLimited(retryAfter)
serviceUnavailable
```

Arranque de la app:

1. Cargar la cookie desde almacenamiento seguro.
2. Si no existe, mostrar login.
3. Si existe, ejecutar `GET /auth/me`.
4. Si la sesión es válida, ejecutar `GET /auth/csrf` si el token no vino en la respuesta.
5. Si recibe `401`, borrar cookie y CSRF local y mostrar login.
6. Si hay timeout o `5xx`, conservar la sesión y ofrecer reintento; no interpretar una caída como credenciales inválidas.

Login:

1. Usuario y contraseña empiezan vacíos; se eliminan las credenciales precargadas de la demo.
2. Deshabilitar el botón mientras la solicitud está activa y evitar envíos duplicados.
3. Enviar `device_name` genérico y `client_platform=android`; no usar identificadores publicitarios ni un fingerprint invasivo.
4. Ante éxito, almacenar cookie/CSRF, descartar inmediatamente la contraseña y cargar `/auth/me`.
5. Ante `401`, mostrar un mensaje único: “No pudimos iniciar sesión con esos datos”.
6. Ante `429`, respetar `Retry-After`, bloquear temporalmente el botón y mostrar el tiempo restante.
7. No distinguir en la interfaz usuario inexistente, deshabilitado o fuera del piloto.

Logout:

1. Enviar `POST /auth/logout` con CSRF.
2. Borrar siempre el material local, incluso si la sesión ya venció o la red falla.
3. `logout-all` debe tener confirmación explícita y, si el contrato lo requiere, reautenticación.

### Capacidades

Modelar las capacidades recibidas, pero mantener tarjetas funcionales deshabilitadas. El inicio deberá indicar que el acceso está conectado al portal y que los módulos aún están en preparación.

La app nunca inferirá permisos por rol, nombre de usuario o correo. Sólo usará capacidades informativas para la interfaz; el servidor autorizará cada operación futura.

Criterio de salida: la app autentica al usuario piloto, recupera la sesión tras reiniciarse, cierra sesión y maneja expiración/rate limit sin filtrar secretos.

## Fase 3 — Pruebas Flutter

### Unitarias

- Parseo de respuestas correctas y errores.
- Rechazo de URL sin HTTPS o host inesperado.
- Almacenamiento, lectura y borrado de cookie/CSRF.
- Interceptor CSRF sólo para mutaciones y mismo host.
- Redacción de cabeceras y campos sensibles en logs.
- Traducción de `401`, `403`, `429`, timeout y `5xx` a estados de aplicación.

### Widgets

- Campos inicialmente vacíos y contraseña oculta.
- Botón bloqueado durante envío.
- Mensaje genérico ante credenciales inválidas.
- Cuenta regresiva ante rate limit.
- Restauración de sesión muestra el inicio sin repetir login.
- Capacidades falsas dejan módulos deshabilitados.

### Integración con Stage

- Login válido del único usuario piloto.
- Credencial inválida y usuario fuera de allowlist.
- Reinicio completo de la app con sesión vigente.
- CSRF ausente o alterado rechazado por el servidor.
- Logout actual y logout-all.
- Revocación desde servidor mientras la app está abierta.
- Vencimiento por inactividad y absoluto.
- Cambio de contraseña o desactivación del usuario.
- Ausencia de cookies, contraseñas y CSRF en `adb logcat`.
- Instalación release en al menos un dispositivo físico además del emulador.

Las pruebas de integración no guardarán la contraseña en el repositorio ni en argumentos visibles del proceso. Se ingresará mediante un mecanismo secreto del entorno de prueba.

## Fase 4 — Piloto operativo

1. Empezar con una sola cuenta, un dispositivo y una ventana de prueba acordada.
2. Verificar eventos de login, revocación y rate limit en auditoría sin datos sensibles.
3. Observar latencia y tasas `401`, `429` y `5xx`.
4. Probar pérdida de red, cambio Wi-Fi/datos y suspensión prolongada de la app.
5. Documentar incidentes en GLPI vinculados al proyecto y tarea informados.
6. Mantener `APP_API_AUTH_PROVIDER=local_stage`; no iniciar la transición a Keycloak dentro de este corte.

Criterio de salida: una semana de piloto sin exposición de secretos, bypass de allowlist, errores de revocación ni fallos críticos de sesión.

## Fase 5 — Preparación de módulos

Después de aprobar autenticación, implementar un módulo por vez en este orden sugerido:

1. Reservas de salas.
2. Solicitudes de dársenas.
3. Reservas de vehículos.
4. Mis Gastos y archivos.

Salas y dársenas permiten validar primero propiedad, disponibilidad e idempotencia sin incorporar telemetría ni documentos. Vehículos agrega habilitaciones GeoSat y coordinación de regreso. Mis Gastos queda último por su mayor superficie: archivos, datos personales, ARCA, Paperless y flujos de aprobación.

Cada módulo requiere su propio contrato OpenAPI, pruebas IDOR, idempotencia, concurrencia y revisión de datos mínimos antes de cambiar su capacidad a `true`.

## Decisiones pendientes antes de ejecutar

1. Hash final publicado en `origin/WSL-DEV` y OpenAPI exacto.
2. Host HTTPS exacto de Stage que usará el teléfono.
3. Nombre del único usuario piloto inicial, cargado sólo en el entorno del servidor.
4. Duraciones configuradas para inactividad y vencimiento absoluto.
5. Código de error y requisito de reautenticación de `logout-all`.
6. Dispositivo físico destinado a la validación release.

Ninguna de estas decisiones requiere guardar secretos en este repositorio.

## Entregables

- API publicada y verificable en Stage con el flag reversible.
- OpenAPI del piloto.
- Cliente Flutter separado por capas.
- Login real sin credenciales precargadas.
- Almacenamiento seguro de sesión y CSRF.
- Pruebas unitarias, widgets e integración.
- Evidencia sanitizada de cabeceras de cookie y casos de revocación/rate limit.
- Informe de piloto y decisión de avanzar o corregir antes del primer módulo.
