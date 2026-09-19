# Leiva App Interna — siguiente corte: reservas de salas

> Estado al 18/09/2026: implementado y publicado por Capital Inversiones en
> `origin/WSL-DEV` (`88e817b743fd4a1a17a016016c6d658dd5980fd2`). Flutter
> consume el contrato descrito abajo. Este documento se conserva como
> trazabilidad del pedido original.

## Mensaje para el Codex de Capital Inversiones

Partí de `sistemas-leivahnos/WSL-Capital-Inversiones`, rama `WSL-DEV`, y ejecutá
`git fetch origin --prune` antes de modificar. El estado verificado desde el
proyecto Flutter el 18/09/2026 es:

- `origin/WSL-DEV`: `6f046df1873bfd26f9204791f2ec69cd00679763`;
- la autenticación móvil real bajo `/api/app/v1/auth` funciona desde Android;
- el router móvil sólo incluye `auth.router`;
- `_capabilities()` mantiene todos los módulos en `false`;
- todavía no existen routers móviles de salas, estacionamiento, vehículos o
  gastos en `app/api/app_v1`.

Implementá como siguiente corte únicamente **Reservas de salas**, reutilizando
`MeetingRoomReservationService`, `MeetingRoomNotificationService` y
`ParkingMeetingRoomCoordinator`. No expongas rutas HTML ni dupliques reglas de
negocio en el router móvil.

## Contrato requerido

Agregar bajo `/api/app/v1`:

| Método y ruta | Alcance |
|---|---|
| `GET /branches` | Sucursales activas con los campos mínimos necesarios. |
| `GET /rooms?branch_id=` | Salas activas, capacidad y equipamiento interno publicable. |
| `GET /rooms/availability?branch_id=&from=&to=&capacity=` | Disponibilidad sin identidad ni detalles de reservas ajenas. |
| `GET /room-reservations?from=&to=&cursor=` | Sólo reservas donde el usuario autenticado participa, organiza o es responsable. |
| `GET /room-reservations/{id}` | Sólo participante, organizador, responsable o gestor ya autorizado; responder `404` para recursos ajenos. |
| `POST /room-reservations` | Crear reserva propia mediante el servicio existente. Requiere CSRF e `Idempotency-Key`. |
| `PATCH /room-reservations/{id}` | Editar sólo en estados y alcances permitidos. Requiere CSRF. |
| `POST /room-reservations/{id}/cancel` | Cancelar con motivo y coordinar la cancelación de estacionamiento vinculado. |
| `POST /room-reservations/{id}/withdraw` | Retirar sólo al participante autenticado. |

Todas las fechas deben incluir zona horaria y responder en UTC. Los esquemas
Pydantic de entrada deben usar `extra="forbid"`, longitudes máximas y listas
cerradas para estados o acciones.

## Autorización obligatoria

1. Resolver usuario y empleado desde la sesión opaca; no aceptar `user_id`,
   `employee_id`, rol ni permiso desde Flutter.
2. Recalcular usuario activo y permisos en cada solicitud.
3. Filtrar propiedad y participación dentro de la consulta a base de datos.
4. Responder `404` para una reserva ajena cuando no corresponda revelar que
   existe.
5. Revalidar permiso y propiedad en cada lectura y mutación.
6. No devolver nombres, correos, notas ni motivos de reservas ajenas al informar
   disponibilidad.
7. Mantener administración de salas y vistas generales fuera de la API móvil.

## Integridad

- Ejecutar comprobación de disponibilidad y escritura en una sola transacción.
- Bloquear el recurso y volver a comprobar superposiciones antes del `INSERT` o
  actualización.
- Devolver `409 reservation_conflict` si el horario dejó de estar disponible.
- Implementar `Idempotency-Key` por usuario, método y ruta para la creación; un
  reintento equivalente devuelve el resultado original y una reutilización con
  otro cuerpo devuelve `409`.
- Conservar las notificaciones y la coordinación opcional con estacionamiento
  del servicio existente.

## Capacidad

Reemplazar el valor fijo únicamente para `room_reservations` por un cálculo
servidor basado en usuario activo, vínculo de empleado y permisos reales:

```json
"room_reservations": {
  "view": true,
  "create": true
}
```

No cambiar las capacidades de estacionamiento, vehículos ni gastos. Si el
usuario no cumple los requisitos, devolver ambos valores en `false`. El backend
debe autorizar cada endpoint aunque Flutter oculte el módulo.

## Pruebas y entrega

Antes de habilitar la capacidad en Stage:

- pruebas de sesión ausente, vencida y revocada;
- pruebas de CSRF en todas las mutaciones;
- pruebas de usuario fuera del piloto y sin permiso;
- pruebas IDOR para listado, detalle, edición, cancelación y retiro;
- conflicto por solicitudes simultáneas sobre la misma sala y horario;
- repetición y reutilización inválida de `Idempotency-Key`;
- validación de fechas, duración, textos, correos y paginación;
- confirmación de que disponibilidad no filtra datos de terceros;
- OpenAPI actualizado y ejemplos sanitizados;
- pruebas existentes de autenticación y del portal completas.

Publicá el commit en `origin/WSL-DEV` y confirmá:

1. hash publicado;
2. endpoints implementados;
3. pruebas ejecutadas y resultado;
4. fragmento OpenAPI del módulo;
5. despliegue de Stage y usuario piloto habilitado;
6. respuesta sanitizada de `/auth/me` mostrando sólo
   `room_reservations.view/create=true`.

No desplegar a producción ni habilitar los otros tres módulos en este corte.

## Trabajo posterior en Flutter

Con el contrato publicado y Stage validado, el proyecto Flutter agregará:

- cliente y repositorio de salas;
- listado de reservas propias;
- consulta de disponibilidad;
- alta idempotente;
- detalle, edición, cancelación y retiro según capacidades;
- manejo de `401`, `403`, `404`, `409`, `422` y `429`;
- pruebas de widgets e integración contra Stage.
