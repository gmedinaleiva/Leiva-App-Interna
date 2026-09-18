# Reglas de trabajo

## Carpeta autorizada

Todas las escrituras del proyecto deben permanecer dentro de:

`C:\Users\gmedina\OneDrive - LEIVA HERMANOS S A\Proyectos Leiva\Leiva-App-Interna`

Antes de escribir, verificar la ubicación actual y la raíz devuelta por `git rev-parse --show-toplevel`. Resolver los destinos a rutas absolutas y comprobar que sean la carpeta autorizada o descendientes de ella. No escribir mediante enlaces o junctions que apunten fuera de esta carpeta. Usar explícitamente esta carpeta como directorio de trabajo de los comandos.

Si la ruta no coincide, detener las escrituras y corregir el directorio de trabajo. No modificar archivos ni configuraciones globales fuera de esta carpeta sin autorización expresa.

## Git

Repositorio: https://github.com/gmedinaleiva/Leiva-App-Interna.git

Trabajar en ramas específicas por tarea: `feat/<tarea>`, `fix/<tarea>` o `chore/<tarea>`. Revisar la rama y el estado de Git antes de modificar archivos. No trabajar directamente sobre `main` ni `master`. No descartar cambios existentes ni reescribir historial sin autorización expresa.

Rama inicial: `chore/project-setup`.
