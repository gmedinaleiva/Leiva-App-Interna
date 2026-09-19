# Referencia vigente: Capital Inversiones Stage

## Verificación vigente de la API móvil

El 18/09/2026 se verificó nuevamente `origin/WSL-DEV` en
`88e817b743fd4a1a17a016016c6d658dd5980fd2`. Este corte incorpora el router
móvil de reservas de salas, su migración de idempotencia y sus pruebas. El
servidor habilita `room_reservations.view/create` según el usuario y conserva
vehículos, estacionamiento y gastos deshabilitados.

Las rutas de salas también fueron verificadas en Stage sobre
`https://monitor.leivahnos.com.ar/api/app/v1`: sin sesión responden `401`
JSON, lo que confirma que están publicadas sin exponer datos anónimos.

Revisión estática realizada el 18/09/2026 sobre el código publicado en GitHub.

| Dato | Referencia verificada |
|---|---|
| Repositorio canónico | `git@github.com:sistemas-leivahnos/WSL-Capital-Inversiones.git` |
| Rama | `WSL-DEV` |
| Commit remoto vigente | `88e817b743fd4a1a17a016016c6d658dd5980fd2` |
| Checkout de origen | `/opt/stacks/capital-inversiones-stage/capital-inversiones` |
| Rama de la app Flutter | `DEV` de `gmedinaleiva/Leiva-App-Interna` |

La consulta remota con `git ls-remote` confirmó que `origin/WSL-DEV` apunta al commit indicado. `master` pertenece a una línea anterior y no representa Capital Inversiones Stage. El relevamiento funcional amplio que sigue se originó en `da5ccd7`; la verificación puntual del módulo móvil de salas fue realizada sobre `88e817b`.

La revisión previa del repositorio `gmedinaleiva/capital-inversiones` en `7ee9fcae3d51c960aaab88a6a797db9a8c69afe0` queda reemplazada por este documento. Sus conclusiones sobre estética, autenticación, módulos y APIs no deben usarse para desarrollar la aplicación Flutter.

## Arquitectura actual

Capital Inversiones es una plataforma interna amplia construida con FastAPI, SQLAlchemy, Alembic, PostgreSQL, Jinja2, CSS y JavaScript. El servidor combina páginas HTML, formularios, redirecciones y endpoints JSON. La aplicación registra decenas de routers y conserva la lógica de negocio, integraciones y permisos en el backend.

Para Flutter conviene mantener esa lógica en Capital Inversiones y consumir contratos del servidor. Cada módulo deberá relevarse de forma individual porque no hay un único formato transversal: algunas rutas entregan JSON, otras HTML o archivos, y otras procesan formularios.

## Identidad visual vigente

El login actual usa una composición dividida y adaptable: panel institucional rojo con ilustración del edificio y panel de acceso claro. La tipografía principal es Inter. Los colores observados en el commit son:

| Uso | Color |
|---|---|
| Gradiente institucional | `#E11D25`, `#C70F19`, `#980811` |
| Acción y acento | `#DC1F26` |
| Texto principal | `#111827` |
| Texto secundario | `#4B5563`, `#7B8494`, `#8A94A6` |
| Fondo | gradiente `#FBFCFF` a `#EEF2F7` |
| Superficie | `#FFFFFF` |
| Bordes de campos | `#DCE2EA` |

El sistema también contempla preferencias de tema `system`, `light`, `dark`, `dark_contrast` y `dark_warm`, además de interfaz `classic` o `v2`. La app Flutter debe traducir estos elementos a un tema compartido y a diseños adaptables para Android y web.

## Autenticación y autorización

- `POST /login` recibe usuario y contraseña como formulario, autentica contra usuarios persistidos y crea una sesión firmada.
- La cookie de sesión tiene nombre, duración, dominio, ruta, `SameSite` y uso exclusivo de HTTPS configurables por entorno. En el código vigente, HTTPS está activado por defecto.
- Se registran eventos de inicio correcto, fallo y cierre de sesión.
- El perfil permite cambiar contraseña y preferencias visuales. La política exige ocho caracteres, una mayúscula, un número y un carácter especial.
- El acceso se controla mediante rol, permisos específicos y dependencias por módulo. Los simuladores financieros, Garantías, FAL, Proveedores, Subproductos, GeoSat, ESCO e Interbanking tienen controles dedicados.

No debe asumirse que existe JWT ni una API móvil de autenticación. Para Android hay que definir cómo se conservará y renovará la sesión. Para Flutter web se debe confirmar el origen de despliegue y la política de cookies/CORS. Estas decisiones requieren validar el contrato real del entorno Stage antes de implementar el cliente.

## Módulos observados

La rama vigente incluye, entre otros:

- Dashboard comercial, simuladores, cauciones, cheques, portafolio, garantías, sintéticos, BCRA y entregables LECAP.
- Simulador FAL con catálogo y permisos propios.
- Proveedores, gastos y rendiciones, caja chica y circuitos de recepción, validación, aprobación, tesorería y auditoría.
- Interbanking clásico y v2, con panel, transferencias, movimientos, extractos, saldos, historial y conciliación.
- Subproductos: contratos por kilos, transportes, CPE, facturas, validación ARCA, ingestión Cargill/LDC, trazabilidad y documentos en Paperless v3.
- GeoSat: flota, reservas, movilidad, telemetría, combustible, operaciones y radares.
- ESCO: vistas internas, analytics, primary, reportes, gestión y mesa de operaciones.
- ARCA interno y externo, auditoría, reservas de salas, estacionamiento y presupuesto de IT.
- Administración de usuarios, permisos, integraciones y tareas operativas.

El commit de referencia contiene 161 rutas solamente en el router de Proveedores, 98 en Administración, 56 en GeoSat y 42 en ARCA Lab. La primera versión de Flutter necesita un alcance funcional explícito; intentar reproducir todo el portal en una sola etapa sería difícil de validar.

## Cambios recientes relevantes

El historial que culmina en `da5ccd7` registra la integración y el endurecimiento de Paperless v3, el flujo de Subproductos, ingestión documental de Cargill y LDC, validación fiscal ARCA, conciliación CPE, trazabilidad de vistas previas, restricciones de navegación y requisitos del circuito de presupuesto de IT.

Estos commits coinciden con el historial mostrado por el usuario y confirman que la referencia actual es mucho más nueva que `7ee9fca`.

## Criterio de integración para Flutter

1. Usar Capital Inversiones como fuente de estética, comportamiento, permisos y contratos; no copiar su backend ni secretos al repositorio Flutter.
2. Definir primero el módulo mínimo viable y documentar por endpoint método, URL, parámetros, respuesta, errores y permiso requerido.
3. Acordar con el backend un contrato de autenticación compatible con Android y web, incluyendo expiración y cierre de sesión.
4. Configurar URLs de Stage y producción mediante variables de compilación de Flutter, sin almacenar credenciales.
5. Implementar componentes visuales compartidos basados en Inter, la paleta institucional y los temas existentes.
6. Verificar cada integración contra `origin/WSL-DEV` y actualizar el commit registrado cuando cambie la referencia.

## Límites de esta revisión

La revisión fue estática. No se ejecutó el portal ni se llamaron servicios de Stage. No se inspeccionaron `.env`, respaldos, datos ni archivos locales sin seguimiento. El repositorio contiene nombres de archivo auxiliares terminados en `:Zone.Identifier`, válidos en Linux pero incompatibles con un checkout normal en Windows; por eso la inspección se realizó directamente desde los objetos Git publicados.

## Fuentes del commit revisado

- [Contexto del proyecto](https://github.com/sistemas-leivahnos/WSL-Capital-Inversiones/blob/da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd/PROJECT_CONTEXT.md)
- [Login](https://github.com/sistemas-leivahnos/WSL-Capital-Inversiones/blob/da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd/app/templates/login.html)
- [Autenticación](https://github.com/sistemas-leivahnos/WSL-Capital-Inversiones/blob/da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd/app/routers/auth.py)
- [Permisos](https://github.com/sistemas-leivahnos/WSL-Capital-Inversiones/blob/da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd/app/dependencies.py)
- [Middleware y routers](https://github.com/sistemas-leivahnos/WSL-Capital-Inversiones/blob/da5ccd7cb4de5b29692d24cd1f23887c1fb27cdd/app/main.py)
