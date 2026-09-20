# Lineamientos UX transversales

Estado: recibidos y documentados; no implementados.

Estos criterios aplican a más de un módulo y deben revisarse junto con cada
caso funcional antes de comenzar la implementación.

## Mapas y planos a pantalla completa

Todos los mapas cartográficos deben ofrecer una acción visible para maximizar
su contenido a pantalla completa, con una experiencia comparable a una app de
GPS. Los planos interactivos, como el de dársenas, también deben poder ampliarse
cuando el tamaño del teléfono impida operar cómodamente.

El modo ampliado debe:

- usar todo el espacio disponible respetando las áreas seguras del dispositivo;
- funcionar en orientación vertical y horizontal;
- conservar posición, zoom, filtros, recorrido y marcador seleccionado al
  entrar o salir;
- ofrecer controles claros para cerrar, acercar, alejar, encuadrar todo el
  recorrido y volver al punto o vehículo relevante;
- permitir desplazamiento y zoom mediante gestos táctiles habituales;
- mantener visibles o accesibles la leyenda y las capas de eventos;
- mostrar el detalle del marcador seleccionado en una tarjeta u hoja inferior
  sin ocultar permanentemente el mapa;
- evitar que encabezados y navegación inferior resten espacio durante el modo
  pantalla completa;
- restaurar el contexto exacto al volver a la vista del módulo.

La acción de centrar posición debe distinguir entre posición del vehículo
obtenida por GeoSat, punto seleccionado y ubicación del teléfono. La app no
solicitará GPS del teléfono mientras esa capacidad continúe fuera de alcance.

## Icono oficial de la aplicación

El icono del launcher debe utilizar el logo oficial real de Leiva, obtenido de
un recurso corporativo canónico. No se debe redibujar, aproximar ni generar un
logo alternativo.

Al implementar se prepararán variantes Android adaptativas:

- capa de primer plano con proporciones y margen seguro del logo;
- fondo con color corporativo aprobado;
- tamaños rasterizados requeridos por Android;
- variante monocromática cuando el recurso oficial y la versión de Android lo
  permitan;
- verificación en icono normal, máscara circular y otras formas de launcher.

El archivo fuente debe conservar buena resolución o formato vectorial. Antes
de sustituir el icono actual se identificará cuál de los logos corporativos es
el aprobado específicamente para la app interna.

## Recursos visuales originales del portal

Cuando un recurso fue diseñado específicamente para una función del portal,
la app debe reutilizar el recurso original o una adaptación fiel, con permiso y
trazabilidad de origen. No debe reemplazarse por un icono genérico si eso reduce
la comprensión funcional.

Esto aplica especialmente a los automóviles del plano de dársenas. Al iniciar
la implementación se solicitarán al anfitrión los archivos fuente, variantes y
reglas de color disponibles en el repositorio del portal.

