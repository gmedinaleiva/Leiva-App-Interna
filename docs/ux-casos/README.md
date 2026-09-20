# Casos UX de referencia

Este directorio conserva las pantallas y decisiones funcionales que se usarán
para acercar la experiencia móvil al portal. Durante la etapa de recopilación
no se implementan cambios de código. La implementación comenzará cuando el
usuario confirme que terminó de enviar la serie de casos.

## Estado

| Sección | Documento | Estado |
| --- | --- | --- |
| Lineamientos transversales | [00-lineamientos-transversales.md](00-lineamientos-transversales.md) | Recibidos, pendientes de implementación |
| Reserva de salas | [01-reserva-de-salas.md](01-reserva-de-salas.md) | Recibida, pendiente de implementación |
| Reserva de dársenas | [02-reserva-de-darsenas.md](02-reserva-de-darsenas.md) | Recibida, pendiente de implementación |
| Mis Gastos | [03-mis-gastos.md](03-mis-gastos.md) | Recibida, pendiente de implementación |
| Reserva de vehículos | [04-reserva-de-vehiculos.md](04-reserva-de-vehiculos.md) | Recibida, pendiente de implementación |

## Criterios generales

- El portal y `/api/app/v1` siguen siendo la fuente funcional y de permisos.
- La app adapta la composición a una pantalla móvil sin eliminar datos o
  acciones autorizadas para el empleado.
- No se inventan rutas, campos, estados ni permisos que no estén publicados en
  el contrato de la API.
- Las acciones destructivas requieren confirmación antes de enviarse.
- Cada sección debe comprobar persistencia y paridad entre portal web y Android
  antes de marcarse como terminada.
