# Caso UX 01: Reserva de salas

Estado: recibido y documentado; no implementado.

Fuente visual: seis capturas del portal entregadas por el usuario el
20/09/2026. La reproducción debe ser lo más cercana posible en identidad,
jerarquía y comportamiento, adaptada a Android.

## Objetivo móvil

La entrada del módulo debe priorizar lo que el empleado necesita hacer ahora:
ver sus reservas activas y vigentes, identificar la sala y sucursal, y acceder
rápidamente a reservar, reprogramar, editar o cancelar. El historial no debe
ocupar la pantalla principal; debe abrirse mediante una navegación separada.

Al consultar disponibilidad, la app debe permitir cambiar de sucursal y sala.
La selección inicial observada en el portal es Echagüe, pero en móvil conviene
mostrar directamente las salas que el usuario tenga reservadas en cualquiera
de sus sucursales. Si no hay reservas activas, se debe destacar la acción para
crear una nueva.

## Imagen 1: página central

Elementos observados:

- cabecera destacada en rojo con `Reservas de salas`, explicación breve y
  cantidad de salas disponibles;
- selector de sucursal;
- tarjetas de salas de la sucursal seleccionada, con nombre, sucursal y
  recordatorio configurado;
- bloque `Mis reservas próximas`;
- alternancia visual entre grilla y agenda;
- acción `Nueva reserva`;
- cada reserva muestra fecha, rango horario, sala, sucursal, título,
  responsable, participantes y estado;
- acciones `Reprogramar`, `Editar` y `Cancelar`.

Adaptación requerida:

- primera zona: reservas activas/vigentes del empleado, agrupadas o
  identificadas por sucursal;
- no mostrar el historial completo en esta vista;
- incluir acceso visible a `Historial de reservas`;
- mantener una acción principal para `Reservar sala`;
- conservar una vista de disponibilidad por sucursal/sala sin convertir la
  tabla web en una tabla horizontal difícil de usar en el teléfono;
- usar tarjetas verticales con estado y acciones contextuales.

## Imagen 2: nueva reserva global

El alta contiene:

- sala;
- fecha;
- hora desde y hasta, expresadas en horario de Argentina;
- motivo o título;
- búsqueda y selección de participantes internos;
- participantes externos con tipo, nombre y apellido, empresa/organización y
  correo opcional;
- posibilidad de agregar más de una persona externa;
- opción `Al confirmar, elegir dársena para las personas externas`;
- explicación de que la solicitud de estacionamiento queda pendiente de
  autorización de Recepción/Guardia;
- observación para Recepción y participantes;
- acciones `Cancelar` y `Confirmar reserva`.

La reserva de dársena debe mantenerse vinculada a la reserva de sala y a las
personas externas correspondientes. La app no debe presentar esa coordinación
como una reserva independiente sin contexto.

## Imagen 3: reserva activa y vigente

La reserva activa debe mostrar como mínimo:

- fecha y rango horario;
- sala y sucursal;
- motivo;
- responsable;
- cantidad o lista accesible de participantes;
- estado confirmado u otro estado devuelto por el portal;
- acciones disponibles según propiedad, estado y permisos.

La acción principal depende del momento y estado. `Reprogramar`, `Editar` y
`Cancelar` sólo deben habilitarse cuando la API los autorice.

## Imagen 4: reprogramar

El modal observado contiene:

- título `Reprogramar reserva`;
- nuevo horario desde y hasta, en horario de Argentina;
- motivo opcional del cambio;
- acciones `Cancelar` y `Confirmar nuevo horario`.

En móvil debe abrirse como hoja o pantalla modal con selectores nativos de
fecha/hora, mostrar la reserva que se está modificando y conservar los datos
anteriores hasta confirmar. La app debe presentar conflictos de horario con el
mensaje exacto del portal y permitir corregirlos sin perder la carga.

## Imagen 5: editar

La edición observada permite modificar:

- sala, fecha, hora desde y hasta;
- motivo o título;
- participantes internos existentes, con posibilidad de quitarlos o agregar
  otros;
- participantes externos con tipo, nombre, organización/proveedor y correo;
- observación;
- coordinación de estacionamiento cuando corresponda.

La UI debe distinguir participantes internos y externos y mostrar claramente
qué datos son obligatorios según el tipo de visitante. Los valores vigentes se
cargan antes de editar y no se descartan ante un error de validación.

## Imagen 6: cancelar

La captura muestra el resultado exitoso: `Reserva cancelada; la sala quedó
disponible`, con acceso a la agenda.

Cambio solicitado respecto del comportamiento observado:

1. Al tocar `Cancelar`, mostrar primero una confirmación explícita.
2. La confirmación debe identificar sala, sucursal, fecha y horario.
3. Debe explicar el efecto sobre participantes y dársenas vinculadas cuando la
   API lo determine.
4. La opción segura `Conservar reserva` debe poder cerrarla sin efectos.
5. Sólo después de confirmar se envía la cancelación.
6. Mostrar progreso para evitar envíos dobles.
7. Ante éxito, mostrar el resultado y actualizar reservas activas y
   disponibilidad.
8. Ante error o conflicto, conservar la reserva visible y presentar el mensaje
   del servidor.

## Navegación móvil propuesta para validar al implementar

- `Salas`: reservas activas y próximas del empleado.
- `Disponibilidad`: sucursal, salas y agenda consultable.
- `Nueva reserva`: flujo completo de alta.
- `Historial`: reservas pasadas y canceladas, con filtros.
- Detalle de reserva: información completa y acciones autorizadas.

Esta estructura es una interpretación para pantalla móvil. Debe validarse
contra las rutas y capacidades vigentes antes de implementarse.

## Criterios de aceptación pendientes

- Ver sólo reservas propias activas/vigentes en la entrada del módulo.
- Poder navegar al historial sin mezclarlo con la vista principal.
- Consultar disponibilidad por sucursal y sala.
- Crear una reserva con participantes internos y externos.
- Solicitar dársenas para visitantes dentro del mismo flujo.
- Abrir el detalle de una reserva y reflejar el mismo estado que el portal.
- Reprogramar y editar sin perder datos ante validaciones.
- Pedir confirmación antes de cancelar.
- Refrescar disponibilidad, reserva y dársenas después de cada mutación.
- Respetar estados, capacidades, errores e idempotencia definidos por
  `/api/app/v1`.

## Puntos a resolver al cerrar la recopilación

- criterio exacto para considerar una reserva `activa y vigente`;
- sucursal inicial cuando el usuario no tenga una reserva activa;
- presentación preferida de disponibilidad: agenda diaria, semanal o ambas;
- comportamiento de participantes y dársenas al reprogramar o cancelar;
- textos finales de confirmación y éxito;
- alcance de recordatorios dentro de la app y por push.

