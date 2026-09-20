# Caso UX 04: Reserva de vehículos

Estado: recibido y documentado; no implementado.

Fuente visual: diez capturas del portal entregadas por el usuario el
20/09/2026. La experiencia móvil debe conservar la relación entre vehículos
habilitados, reservas, agenda asignada, viajes, avisos y trayectoria GeoSat.

## Principio funcional

El módulo debe distinguir cinco conceptos:

- vehículos que el empleado está habilitado a reservar;
- solicitudes o reservas creadas por el empleado;
- itinerarios asignados por Gerencia;
- viajes efectivamente realizados;
- datos y eventos de la trayectoria capturada por GeoSat.

Las reservas pendientes y activas tienen prioridad en la entrada. Los viajes y
reservas cerrados, cancelados u otros estados históricos deben quedar en vistas
de historial con acceso a sus datos y trayectorias cuando existan.

La ubicación vehicular proviene de GeoSat a través del portal. Este módulo no
usa ni solicita la ubicación GPS del teléfono.

## Imagen 1: Mi movilidad

### Cabecera y resumen

La cabecera observada contiene identidad visual roja, el título `Mi movilidad`,
una explicación breve, el empleado autenticado y la acción `Nueva reserva`.

El resumen presenta cinco KPI interactivos:

1. vehículos habilitados;
2. mis reservas activas;
3. historial de reservas;
4. mi agenda activa;
5. historial de agenda.

Cada tarjeta debe mostrar su contador real y abrir una vista o modal dedicado.
En móvil los KPI pueden organizarse como tarjetas desplazables o una grilla de
dos columnas, pero deben conservar título, cantidad y destino inequívoco.

### Solicitudes, reservas y viajes

La grilla web observada incluye vehículo, destino, período, estado y accesos a
trayectoria o datos/eventos. También incluye prefiltros por períodos de tiempo.

La adaptación móvil debe:

- colocar primero solicitudes pendientes, reservas confirmadas próximas y
  viajes activos;
- permitir filtrar por períodos publicados por el portal;
- separar el historial de reservas y viajes con otros estados;
- mostrar en tarjetas vehículo, dominio, destino, rango, estado y acciones;
- habilitar `Ver trayectoria` sólo cuando exista información GeoSat;
- habilitar `Ver datos y eventos` según el estado y las capacidades reales;
- explicar `Viaje no iniciado` u otras razones cuando todavía no haya datos.

El orden debe priorizar urgencia y vigencia antes que una cronología completa.
La app no debe mezclar reservas futuras con viajes históricos sin una etiqueta
o sección clara.

## Imagen 2: nueva reserva

El modal de alta observado contiene:

- vehículo habilitado;
- fecha y hora desde, en horario de Argentina;
- fecha y hora hasta;
- destino;
- motivo;
- ocupantes totales, incluido el conductor;
- equipaje o carga estimada en kilogramos;
- dársena al regresar;
- tiempo de estacionamiento;
- distancia estimada opcional;
- política de retorno;
- observación;
- acción `Confirmar reserva`.

La dársena de regreso se solicita dentro de este flujo. El margen observado es
de 60 minutos y su cálculo o validación ya lo resuelve el backend. Flutter debe
mostrar la opción y el resultado del servidor sin duplicar esa regla localmente.

La política observada indica que se espera el regreso a la sucursal de origen;
si el vehículo sigue lejos, el viaje puede extenderse operativamente y Flota
recibe un aviso. La app debe mostrar estas condiciones antes de confirmar.

Mientras el viaje está en curso deben verse los avisos vigentes relacionados
con la reserva, el vehículo o su trayectoria. Esos avisos deben integrarse con
la futura bandeja interna y con push cuando FCM esté activo, pero siempre abrir
el recurso autorizado y actualizado del portal.

Después de confirmar, la app debe actualizar la reserva, la agenda personal y
la solicitud de dársena vinculada. Debe impedir envíos duplicados y conservar el
formulario ante errores de validación o conflictos.

## Imagen 3: KPI Vehículos habilitados

La vista lista únicamente vehículos que el backend habilitó para el empleado.
Cada elemento observado incluye:

- dominio;
- marca y modelo;
- condición `Habilitado para reservar`.

Flutter no administra habilitaciones. Si un vehículo deja de estar autorizado,
debe desaparecer o mostrar el estado que determine el portal, y no puede
seleccionarse en una nueva reserva.

## Imagen 4: KPI Mis reservas activas

La vista reúne reservas pendientes, confirmadas o vigentes según la definición
del backend. Debe ofrecer un estado vacío claro cuando no existan reservas.

Cada tarjeta debe permitir abrir el detalle y las acciones autorizadas para su
estado, como editar, cancelar, iniciar o consultar avisos, únicamente si esas
capacidades están publicadas por la API.

## Imagen 5: KPI Historial de reservas

El historial observado muestra vehículo, período, destino/motivo, estado y
acceso a viaje y eventos cuando existen. Debe reunir reservas finalizadas,
cerradas, canceladas u otros estados históricos reales.

La disponibilidad de trayectoria no se deduce sólo del estado: debe provenir
del servidor. Una reserva cancelada o un viaje no iniciado puede no tener
trayectoria.

## Imagen 6: KPI Mi agenda activa

Gerencia puede asignar al empleado visitas a clientes con:

- vehículo;
- lugar o destino;
- fecha y horario;
- instrucciones o motivo;
- demás información operativa publicada por el portal.

Esta sección muestra exclusivamente el itinerario activo asignado por Gerencia.
Debe distinguirlo de las reservas creadas por el propio empleado. La edición o
confirmación sólo estará disponible si el backend la permite; la app no debe
convertir una agenda gerencial en una reserva editable por defecto.

## Imagen 7: KPI Historial de agenda

La referencia actual parece repetir el historial de viajes. El comportamiento
deseado es diferente: esta vista debe contener únicamente asignaciones de
agenda creadas por Gerencia que ya finalizaron, se cancelaron o dejaron de
estar activas.

No debe reutilizar el historial general de reservas o viajes como sustituto.
Si el contrato actual no diferencia el origen gerencial, la implementación se
detendrá para pedir al anfitrión un campo o una ruta canónica.

Cada elemento debe permitir consultar los datos originales de la asignación y,
si existe un viaje relacionado, navegar a él mediante una relación explícita,
sin duplicar ambas entidades.

## Imágenes 8 y 9: trayectoria y eventos

El modal `Mi viaje y eventos` muestra un viaje finalizado y ofrece actualizar
la posición cuando corresponda. La vista combina métricas, mapa, puntos
capturados y eventos relevantes.

### Resumen observado

- distancia recorrida;
- cantidad de puntos capturados;
- velocidad máxima;
- posición o velocidad actual;
- fecha de la última señal y advertencia si es anterior al viaje;
- eventos sostenidos;
- eventos breves;
- detenciones;
- combustible;
- multas;
- posibles excesos estimados;
- radares.

Las métricas deben ser interactivas cuando tengan elementos asociados. Al
tocarlas, la app debe filtrar o abrir su listado y permitir centrar el evento
correspondiente en el mapa.

### Mapa

El mapa observado utiliza cartografía OpenStreetMap y debe representar:

- recorrido completo;
- sentido de circulación;
- inicio;
- última posición histórica;
- posición actual cuando exista;
- puntos de captura relevantes;
- excesos de velocidad;
- radares;
- detenciones o `stops`;
- duración de cada detención;
- otros avisos publicados para el viaje.

Los marcadores deben diferenciarse también por icono o etiqueta, no solamente
por color. Al tocar un marcador se debe mostrar hora, ubicación y datos del
evento. La app debe poder encuadrar toda la trayectoria y luego volver al punto
seleccionado sin perder filtros.

La línea debe indicar el sentido del viaje mediante flechas u otra señal
visual. Un recorrido con muchos puntos debe agruparse o simplificarse para
mantener rendimiento sin alterar los eventos relevantes.

El mapa debe incluir una acción de maximizar. En pantalla completa debe
comportarse como un navegador GPS: ocupar el área útil completa, admitir gestos
de zoom y desplazamiento, funcionar en vertical u horizontal, encuadrar la ruta,
centrar el vehículo o evento seleccionado y permitir volver sin perder filtros,
marcador ni posición de cámara.

### Actualización y seguridad

`Actualizar posición` consulta nuevamente al portal/GeoSat. No inicia rastreo
del teléfono. La app sólo muestra reservas y trayectorias propias autorizadas;
un deep link o identificador recibido nunca sustituye la validación del
servidor.

## Imagen 10: detalle desde un KPI de trayectoria

El ejemplo `Posibles excesos estimados` lista eventos con:

- ruta y kilómetro;
- estimación preventiva;
- velocidad GPS;
- límite oficial o estimado;
- tolerancia aplicada;
- punto GPS del equipo;
- precisión aproximada;
- indicación de que no constituye una infracción;
- fecha y hora;
- duración;
- distancia;
- acción `Ver punto en el mapa`.

Al tocar esa acción, el modal debe volver o desplazarse al mapa, centrar el
punto exacto, resaltar su marcador y conservar el contexto del evento. El mismo
patrón debe utilizarse para radares, detenciones, multas y otros KPI cuando el
contrato provea coordenadas.

## Relaciones que deben permanecer visibles

- Empleado → vehículos habilitados por el backend.
- Reserva → vehículo → rango → destino → estado.
- Reserva → dársena de regreso y margen calculado por el backend.
- Agenda gerencial → asignación → empleado → vehículo → destino y horario.
- Reserva o agenda → viaje efectivamente realizado.
- Viaje → trayectoria GeoSat → puntos → eventos y avisos.
- Evento → coordenada y momento exactos → marcador del mapa.

## Navegación móvil propuesta para validar al implementar

- `Movilidad`: pendientes, activas, agenda inmediata y acción de reservar.
- `Reservar`: alta completa con dársena de regreso.
- `Agenda`: asignaciones activas de Gerencia.
- `Historial`: reservas y viajes históricos con filtros.
- `Historial de agenda`: asignaciones gerenciales históricas solamente.
- `Viaje`: datos, eventos y trayectoria.

## Criterios de aceptación pendientes

- Mostrar sólo vehículos autorizados por el backend.
- Priorizar solicitudes pendientes, reservas activas y viajes en curso.
- Separar reservas/viajes históricos de la pantalla principal.
- Registrar una reserva con todos los datos publicados por la API.
- Solicitar una dársena de regreso aplicando el margen del servidor.
- Mostrar avisos durante el viaje.
- Distinguir agenda gerencial de reservas personales.
- Mostrar un historial de agenda exclusivamente gerencial.
- Consultar trayectoria y posición desde GeoSat, sin GPS del teléfono.
- Representar sentido, inicio, posiciones, radares, excesos y detenciones.
- Maximizar la trayectoria a pantalla completa con interacción tipo GPS.
- Mostrar duración de cada detención.
- Abrir los eventos de un KPI y centrar su punto exacto en el mapa.
- Respetar permisos, estados, errores e idempotencia del portal.

## Puntos a resolver al cerrar la recopilación

- estados exactos incluidos en `pendientes`, `activas` y `históricas`;
- rutas o campos que diferencian agenda gerencial de reservas personales;
- acciones que puede realizar el empleado sobre una agenda asignada;
- catálogo completo de eventos GeoSat y sus iconos;
- significado canónico de posición y velocidad actuales;
- estrategia de simplificación o agrupación de trayectorias extensas;
- frecuencia permitida para actualizar posición;
- comportamiento de la dársena si la reserva o el viaje se extiende;
- vínculo entre avisos, multas, estimaciones preventivas y expedientes.
