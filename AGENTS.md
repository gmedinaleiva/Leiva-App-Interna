# Reglas de trabajo

## Carpeta autorizada

Todas las escrituras del proyecto deben permanecer dentro de:

`C:\Users\gmedina\OneDrive - LEIVA HERMANOS S A\Proyectos Leiva\Leiva-App-Interna`

Antes de escribir, verificar la ubicación actual y la raíz devuelta por `git rev-parse --show-toplevel`. Resolver los destinos a rutas absolutas y comprobar que sean la carpeta autorizada o descendientes de ella. No escribir mediante enlaces o junctions que apunten fuera de esta carpeta. Usar explícitamente esta carpeta como directorio de trabajo de los comandos.

Si la ruta no coincide, detener las escrituras y corregir el directorio de trabajo. No modificar archivos ni configuraciones globales fuera de esta carpeta sin autorización expresa.

## Git

Repositorio: https://github.com/gmedinaleiva/Leiva-App-Interna.git

Las ramas del proyecto son `DEV`, `TEST` y `PROD`. `DEV` es la rama principal y de desarrollo; `TEST` se usa para pruebas y `PROD` para producción. Trabajar en `DEV` por defecto. Revisar la rama y el estado de Git antes de modificar archivos. Promover cambios a `TEST` y `PROD` cuando el usuario lo indique. No descartar cambios existentes ni reescribir historial sin autorización expresa.

Rama principal: `DEV`.

## Entorno Flutter

La aplicación interna de Leiva Hermanos SA usa Flutter. Las plataformas iniciales son Android y web.

El usuario autorizó instalar herramientas, SDK, extensiones y sus dependencias fuera del repositorio. Esta excepción incluye configuración de entorno y cachés de las herramientas. Flutter se instala en `C:\Users\gmedina\develop\flutter`; Android SDK en `C:\Users\gmedina\AppData\Local\Android\Sdk`. El código y los archivos del proyecto deben seguir dentro de la carpeta autorizada.

## Portal de referencia

La referencia vigente para estética, módulos, login, APIs y comportamiento funcional es:

- Repositorio remoto: `git@github.com:sistemas-leivahnos/WSL-Capital-Inversiones.git`
- Rama: `WSL-DEV`
- Commit de referencia verificado: `da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd`
- Checkout de origen en el servidor: `/opt/stacks/capital-inversiones-stage/capital-inversiones`

Antes de implementar una integración, ejecutar `git fetch origin --prune`, verificar `origin/WSL-DEV` y registrar el commit consultado en `docs/capital-inversiones-reference.md`. No usar `master` ni el repositorio histórico `gmedinaleiva/capital-inversiones` como referencia. No copiar ni inspeccionar archivos locales sin seguimiento, respaldos, datos o `.env` del servidor; el código confirmado y el historial publicado de `WSL-DEV` son la fuente autorizada.

Capital Inversiones es solamente una referencia externa. La aplicación Flutter continúa en su propio repositorio y su rama de trabajo sigue siendo `DEV`.
