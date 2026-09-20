# Caso UX 02: Reserva de dársenas

Estado: recibido y documentado; no implementado.

Fuente visual: dos capturas del portal entregadas por el usuario el
20/09/2026. La experiencia móvil debe conservar la distribución espacial de
las dársenas, sus estados y el flujo de solicitud, adaptándolos a una pantalla
táctil.

## Objetivo móvil

El módulo debe permitir consultar la disponibilidad de cada sucursal para un
rango de fecha y hora, reconocer visualmente cada dársena en un plano
interactivo y solicitar una disponible. La pantalla principal debe priorizar
las solicitudes pendientes o activas del empleado. Las solicitudes consumidas,
anuladas o canceladas deben quedar en un historial accesible por separado.

La sucursal mostrada por defecto en la referencia es Echagüe. La app debe
respetar la sucursal inicial que determine la lógica funcional y permitir
cambiarla sin perder silenciosamente el rango consultado.

## Imagen 1: pantalla central

### Cabecera

- identidad visual roja del módulo;
- título `Mis solicitudes`;
- explicación de que el empleado elige una dársena verde y que Recepción o
  Guardia debe autorizar la solicitud antes del uso.

### Consulta de disponibilidad

Filtros observados:

- sucursal;
- fecha y hora desde;
- fecha y hora hasta;
- tipo de vehículo;
- acción `Actualizar plano`.

Los filtros deben permanecer visibles y ser fáciles de editar en móvil. Al
actualizar, tanto el plano como los estados relacionados deben corresponder al
mismo rango y sucursal; la UI debe evitar mezclar información de consultas
anteriores.

### Plano interactivo

El plano representa todas las dársenas de la sucursal seleccionada, agrupadas
por sus zonas físicas, pisos, accesos o sectores. En la referencia de Echagüe
se observan sectores separados por circulación vehicular y posiciones en
distintos pisos.

Cada automóvil o posición debe ser táctil y conservar su código identificador.
El color comunica el estado:

- verde: disponible para solicitar en el período consultado;
- amarillo: solicitud pendiente de aprobación;
- rojo: reservada o no disponible por una reserva para ese período;
- gris: asignación permanente o institucional, por ejemplo una dársena
  reservada para directivos.

La app debe incluir una leyenda siempre visible y no depender únicamente del
color: cada posición necesita texto, icono, contorno o etiqueta de estado para
accesibilidad. El plano debe admitir desplazamiento y ampliación cuando no
quepa completo en el teléfono, manteniendo una referencia clara del sector.

Comportamiento al tocar:

- verde: abre la solicitud de reserva;
- amarillo: abre el estado de la solicitud propia si corresponde, sin permitir
  duplicarla;
- rojo: informa que no está disponible en el período consultado;
- gris: informa que es institucional o de asignación permanente y no puede
  solicitarse.

No se debe mostrar la identidad de otra persona ni información de su reserva
salvo que el contrato y los permisos del portal lo autoricen expresamente.

### Estado de mis solicitudes

La grilla web observada muestra:

- rango desde/hasta;
- código de dársena;
- vehículo o dominio;
- estado;
- acciones permitidas, como cancelar.

En móvil debe convertirse en tarjetas legibles. La pantalla principal sólo
debe incluir solicitudes pendientes de autorización, aprobadas que aún no
comenzaron y activas/vigentes. Debe existir un acceso visible a `Historial de
solicitudes` para consultar consumidas, anuladas, rechazadas, vencidas o
canceladas según los estados reales publicados por la API.

Las acciones deben depender del estado y de las capacidades devueltas por el
portal. Toda cancelación debe pedir confirmación e identificar la dársena y el
rango antes de enviar la mutación.

## Imagen 2: solicitar una dársena disponible

Al tocar un automóvil verde se abre un modal o pantalla de solicitud. La
referencia muestra:

- código de la dársena seleccionada;
- confirmación de que está disponible en el rango consultado;
- tipo de vehículo;
- dominio/patente;
- motivo;
- observación opcional;
- acciones `Cerrar` y `Solicitar reserva`.

La selección debe conservar sucursal, dársena y rango provenientes del plano;
el usuario no debe volver a cargarlos ni poder enviar accidentalmente otra
posición. La patente debe validarse con las reglas del portal sin imponer un
formato inventado por el cliente. El motivo y la observación deben respetar
obligatoriedad y límites publicados por la API.

Después de enviar:

- impedir envíos dobles mientras la solicitud está en curso;
- mostrar si quedó pendiente, aprobada o rechazada según la respuesta real;
- actualizar el color del plano y la lista de solicitudes;
- mantener un identificador de idempotencia cuando el contrato lo requiera;
- ante conflicto de disponibilidad, actualizar el plano y explicar que la
  posición dejó de estar disponible;
- ante error de validación, conservar los datos editables.

## Relación con reserva de salas

Las solicitudes de dársena creadas para participantes externos desde una
reserva de sala deben verse en este módulo con el vínculo funcional que exponga
el portal. La app debe poder distinguir una solicitud personal directa de una
coordinada desde una reunión, sin duplicarlas ni romper la autorización de
Recepción/Guardia.

Al editar, reprogramar o cancelar una sala, la app debe mostrar el efecto sobre
las dársenas vinculadas usando exclusivamente las reglas y respuestas de la
API.

## Navegación móvil propuesta para validar al implementar

- `Dársenas`: plano y consulta de disponibilidad.
- `Mis solicitudes`: pendientes, aprobadas y activas.
- `Historial`: consumidas, anuladas, rechazadas, vencidas y canceladas.
- `Detalle`: estado, rango, vehículo, motivo, relación con sala y acciones.

Esta estructura organiza la pantalla móvil; las rutas y estados exactos deben
validarse contra `/api/app/v1` antes de implementarse.

## Criterios de aceptación pendientes

- Consultar por sucursal, rango y tipo de vehículo.
- Ver todas las dársenas de la sucursal en un plano interactivo.
- Distinguir disponible, pendiente, reservada e institucional mediante color y
  etiqueta accesible.
- Abrir la solicitud sólo desde una posición disponible.
- Enviar tipo de vehículo, dominio, motivo y observación válidos.
- Reflejar inmediatamente el estado devuelto por el portal.
- Mostrar sólo solicitudes pendientes o activas en la entrada.
- Navegar a un historial separado.
- Confirmar antes de cancelar una solicitud.
- Mantener la relación con reservas de salas y visitantes cuando exista.
- Aplicar autorización del servidor y no revelar reservas ajenas.

## Puntos a resolver al cerrar la recopilación

- definición exacta de solicitudes `activas` para cada estado del portal;
- sucursal inicial cuando el empleado no tenga solicitudes vigentes;
- nivel de zoom y representación de planos extensos;
- información permitida al tocar posiciones rojas, grises o amarillas ajenas;
- posibilidad de cambiar vehículo o patente después de solicitar;
- reglas de cancelación según proximidad al horario;
- comportamiento exacto de dársenas vinculadas a reservas de salas.

