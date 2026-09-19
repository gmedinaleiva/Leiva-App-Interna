# Prelogin animado Leiva

## Fuente

La integración parte de `docs/LEIVA_FLUTTER_PRELOGIN_TOP4_5S.zip`. El MP4 del
paquete se usa únicamente como referencia visual; la aplicación renderiza la
secuencia con widgets y recursos locales de Flutter.

## Comportamiento

- La secuencia dura cinco segundos y muestra Inversiones, Agro, Seguros y
  Turismo en ese orden.
- El login real se revela desde los 4,05 segundos y queda habilitado a los 4,5.
- El sello Leiva Tech recorre el pie y permanece visible en el login. Se oculta
  mientras el teclado está abierto para no cubrir controles.
- La animación se muestra una vez por ejecución de la aplicación. Al cerrar
  sesión se vuelve directamente al login.
- Si el sistema solicita reducir animaciones, el login aparece inmediatamente.

## Pantalla completa

Android usa modo edge-to-edge y barras transparentes. En orientación vertical,
el lienzo de referencia se escala con `BoxFit.cover` para ocupar el viewport sin
letterboxing. El login móvil elimina la tarjeta exterior, pinta detrás de las
barras del sistema y conserva desplazamiento vertical cuando aparece el teclado.

El arranque nativo y el icono adaptativo usan la identidad roja de Leiva para
evitar que aparezca la marca predeterminada de Flutter antes del primer cuadro.
