# Caso UX 03: Mis Gastos

Estado: recibido y documentado; no implementado.

Fuente visual: cinco capturas del portal entregadas por el usuario el
20/09/2026. El módulo debe reproducir la lógica relacionada de adelantos,
viáticos, caja chica, beneficios, comprobantes, rendiciones, movimientos,
aprobaciones y reintegros, adaptada a Android.

## Principio funcional

`Mis Gastos` no es una colección de formularios independientes. Un adelanto
crea un saldo con tipo y vigencia; los gastos imputados consumen ese saldo; las
rendiciones y movimientos explican su composición; y las reglas del backend
determinan observaciones, autorizaciones, rechazos y reintegros.

La app debe conservar esas relaciones y mostrar de dónde sale cada gasto, qué
saldo consume, qué importe queda disponible y qué trámite posterior requiere.
Los cálculos, políticas fiscales, duplicados y autorizaciones pertenecen al
portal. Flutter muestra y envía datos mediante `/api/app/v1`, sin recalcular ni
decidir reglas contables por su cuenta.

## Navegación observada

La sección contiene accesos a:

- `Inicio`;
- `Viáticos`;
- `Beneficios`;
- `Rendiciones y movimientos`.

En móvil deben mantenerse como destinos claros y conservar el contexto al
volver. Los contadores, saldos y estados deben refrescarse después de registrar
o modificar un movimiento.

## Imagen 1: página de inicio

### Saldos y depósitos

La cabecera muestra:

- saldo vigente;
- indicación de si hay adelantos activos;
- historial de depósitos;
- acceso para registrar un adelanto.

La entrada debe destacar los adelantos vigentes y su saldo disponible. El
historial completo debe quedar en una vista separada para no mezclar saldos
operables con adelantos vencidos, agotados, anulados o cerrados.

### Datos usados en los gastos

El bloque de perfil es de sólo lectura y reúne datos laborales que se aplican
automáticamente:

- nombre;
- apellido;
- correo institucional;
- legajo;
- razón social;
- sucursal;
- departamento.

La app debe señalar qué dato falta y cómo afecta el acceso a viáticos o
beneficios. No debe permitir editar aquí información proveniente del legajo.
Cuando el perfil está completo, debe indicarlo claramente y explicar que la
imputación personal se aplicará automáticamente.

### Bitácora personal de gastos

La bitácora funciona como navegación contextual. Sus tarjetas llevan a:

- viáticos;
- beneficios;
- reservas de vehículos cuando corresponda a gastos asociados.

La relación entre estas áreas debe mantenerse. Una tarjeta puede resumir
pendientes, observaciones o movimientos recientes, pero debe abrir el detalle
real del módulo y no duplicar información local.

## Imagen 2: registrar un adelanto

Un adelanto representa dinero recibido por el empleado y origina un saldo. Se
observan los siguientes datos:

- tipo de saldo;
- importe recibido;
- moneda;
- fecha de acreditación;
- medio recibido;
- fecha desde la que cubre;
- fecha hasta la que cubre;
- nombre opcional para identificarlo;
- referencia bancaria opcional;
- acción `Registrar adelanto`.

Los tipos funcionales descritos por el usuario incluyen:

- adelanto para gastos del día o puntual;
- adelanto mensual;
- adelanto correspondiente a un período entre fechas.

Cada adelanto debe exponer monto original, monto consumido, saldo restante,
vigencia, vencimiento y estado. La app debe usar los tipos y reglas exactos del
backend, especialmente para fechas obligatorias, superposiciones, monedas,
cierre y posibilidad de imputar gastos.

Después de registrar debe actualizarse el saldo vigente y el historial de
depósitos. Los reintentos no deben crear adelantos duplicados.

## Imagen 3: registrar un viático

El empleado puede registrar cuatro situaciones diferentes:

1. gasto pagado de su bolsillo, pendiente de reintegro;
2. gasto asociado a un adelanto del día, que consume su saldo;
3. gasto asociado a un adelanto mensual o por período, que consume su saldo;
4. gasto del departamento, imputado al consumo de caja chica.

La selección de rendición y la imputación a caja chica deben dejar visible cuál
de esas situaciones se está registrando. La app debe explicar el impacto antes
de confirmar y no permitir una combinación incompatible.

Campos observados:

- adelanto o modalidad de reintegro;
- imputación opcional a caja chica;
- fecha del gasto;
- importe;
- moneda;
- rubro;
- viaje o motivo;
- comercio o proveedor;
- número de comprobante o ticket;
- descripción opcional;
- tipo de comprobante;
- archivo de comprobante;
- acciones `Revisar comprobante` y `Registrar gasto`;
- acceso a rendiciones y movimientos de viáticos.

### Tratamiento fiscal

El empleado selecciona una de estas categorías visibles:

- `No estoy seguro`;
- `Es una factura fiscal`;
- `Es ticket o comprobante no fiscal`.

La clasificación determina el procesamiento posterior del expediente en el
backend. La app no debe inferir el resultado final. Puede asistir con la
revisión del archivo, pero debe enviar la opción elegida y mostrar validaciones
o correcciones solicitadas por el portal.

Si el comprobante contiene datos fiscales o QR, el backend puede detectarlos y
validarlos aunque el empleado haya elegido `No estoy seguro`. La UI debe
explicar esa revisión sin prometer aprobación automática.

### Comprobante

Debe admitirse PDF o imagen según el contrato vigente. En Android, el empleado
debe poder:

- elegir un archivo;
- tomar una fotografía del comprobante;
- previsualizarlo antes de enviar;
- reemplazarlo o eliminarlo antes de confirmar;
- ver progreso y errores de carga sin perder el resto del formulario.

No se debe marcar el gasto como registrado hasta que el portal confirme la
persistencia y asociación del comprobante.

## Imagen 4: rendiciones y movimientos

La vista observada permite consultar:

- todos los movimientos;
- viáticos;
- beneficios;
- movimientos con observaciones;
- exportación de una planilla oficial en PDF.

Cada movimiento debe mostrar como mínimo:

- fecha o período;
- tipo;
- comprobante o rendición;
- composición;
- importe;
- estado.

En móvil se utilizarán tarjetas o filas adaptables, con filtros y acceso al
detalle. La exportación debe descargar o compartir el documento oficial
generado por el portal, conservando logo, detalle, totales y conformidades.

La composición debe permitir rastrear qué adelanto o reintegro financia el
movimiento y cómo afectó monto consumido y saldo. No se deben reconstruir esos
cálculos exclusivamente desde datos almacenados en el teléfono.

## Imagen 5: beneficios del empleado

El empleado registra el gasto de un beneficio. Las reglas, topes, períodos y
políticas son administrados por el backend. Flutter no ofrece configuración
administrativa ni permite alterar esas reglas.

Campos observados:

- adelanto compatible o reintegro del mes;
- fecha del gasto;
- importe;
- moneda;
- rubro;
- beneficio utilizado;
- período;
- comercio o proveedor;
- número de comprobante o ticket;
- descripción;
- tipo fiscal del comprobante;
- archivo adjunto;
- acciones para revisar el comprobante y registrar el gasto.

La experiencia debe permitir:

- registrar el beneficio con su comprobante;
- conocer la política aplicable antes de confirmar cuando el backend la
  exponga;
- ver el estado de revisión, aprobación y reintegro;
- recibir y consultar avisos ante exceso, observación, rechazo, cancelación o
  aprobación;
- abrir el motivo y la acción necesaria cuando no se apruebe;
- distinguir una observación corregible de una decisión final.

Los avisos deben integrarse con la futura bandeja interna y, cuando FCM esté
activo, con notificaciones push. La app siempre debe volver a consultar el
estado autorizado en el portal al abrir el aviso.

## Relaciones que deben permanecer visibles

- Adelanto → monto original → consumos → saldo → vigencia/cierre.
- Viático → origen de fondos o reintegro → comprobante → tratamiento fiscal →
  rendición → aprobación/reintegro.
- Caja chica → departamento → consumo → comprobante → revisión.
- Beneficio → política/período → gasto → comprobante → estado → reintegro.
- Movimiento → adelanto o reintegro que lo compone.
- Aviso u observación → expediente afectado → acción que puede realizar el
  empleado.

## Navegación móvil propuesta para validar al implementar

- `Inicio`: saldos vigentes, perfil y bitácora.
- `Adelantos`: vigentes y registro de adelanto.
- `Viáticos`: alta, pendientes y estados.
- `Beneficios`: alta, pendientes y estados.
- `Rendiciones`: movimientos, observaciones y exportación.
- `Historial`: adelantos y gastos cerrados, vencidos, anulados o reintegrados.

Esta organización debe contrastarse con las capacidades y rutas reales antes
de implementarla.

## Criterios de aceptación pendientes

- Mostrar adelantos vigentes con montos original, consumido y disponible.
- Separar adelantos operables del historial.
- Registrar adelantos puntuales, mensuales o por período según el backend.
- Mostrar el perfil laboral de sólo lectura y los datos faltantes.
- Registrar las cuatro modalidades de viático sin combinaciones ambiguas.
- Asociar cada consumo al adelanto, reintegro o caja chica correcto.
- Capturar o adjuntar y previsualizar un comprobante.
- Conservar la clasificación fiscal elegida y el resultado del backend.
- Consultar movimientos, observaciones, aprobaciones y reintegros.
- Exportar el PDF oficial generado por el portal.
- Registrar beneficios respetando políticas y topes del servidor.
- Mostrar avisos y motivos ante observación, rechazo o cancelación.
- Refrescar saldos y estados después de cada operación persistida.
- Evitar duplicados mediante idempotencia y validación del servidor.

## Puntos a resolver al cerrar la recopilación

- catálogo exacto de tipos y estados de adelantos;
- fórmula y momento de actualización de saldos;
- reglas de vencimiento, cierre y devolución de remanentes;
- monedas admitidas y tratamiento de conversiones;
- reglas para imputar caja chica según departamento;
- catálogos de rubros, beneficios y políticas visibles al empleado;
- estados completos de expediente, aprobación y reintegro;
- correcciones permitidas después de observar o rechazar un gasto;
- tamaño, formato y cantidad de comprobantes admitidos;
- comportamiento de detección fiscal, duplicados y validación de QR;
- contenido y disponibilidad de la exportación oficial PDF.

