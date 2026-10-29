# Leiva App Interna 2.2.4 (22400)

Cambios en DEV, 29/10/2026:

- El historial y las tarjetas de reservas distinguen trayectoria disponible,
  sin trayectoria registrada y servidor anterior sin indicador. El detalle
  presenta mensajes explícitos para recorrido vacío y eventos vacíos.
- Provincia y Localidad usan el catálogo autenticado persistido del portal.
  Búsqueda inline sin distinguir tildes; cambiar provincia limpia localidad.
  Sólo admite localidades de esa provincia; rechaza texto fuera del catálogo.
  Respuestas tardías de una provincia anterior no sustituyen la selección actual.
  Disponible en alta y edición de comprobantes de combustible.
- La carga usa prioritariamente los bytes leídos por cámara/selector. No intenta
  abrir como archivo local rutas blob/content cuando ya tiene el contenido.
  Conserva la opción fiscal, la clave idempotente y el resto del formulario.

Backend requerido: `f244b47` de Capital Inversiones, desplegado en Stage.
No contiene cambios de claves Firebase, firma ni publicación a TEST/PROD.
Recompilar en el entorno Android habitual e instalar 2.2.4 para probar cámara
real, ambos tipos fiscales y detalle de viajes sin eventos.

Trazabilidad: GLPI #1287, tarea #261, proyecto #40. No cerrar antes de validar
la instalación y captura con un teléfono real.

Validación en este host con Flutter 3.47.8 / Dart 3.13.7 temporal:
35 pruebas aprobadas, incluidas cinco nuevas (foto unknown/fiscal con ruta
inutilizable, indicador sin eventos, detalle vacío y búsqueda geográfica).
No se ejecutó un emulador Android ni se generó un APK firmado en este host.
Revisión estática final: `flutter analyze --no-pub`, sin observaciones.
