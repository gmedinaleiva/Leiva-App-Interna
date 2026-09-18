# Leiva App Interna

Aplicación Flutter de uso interno de Leiva Hermanos SA. Plataformas iniciales: Android y web.

La pantalla inicial permite comprobar el arranque y la interacción. La integración con el portal de la empresa todavía no está implementada.

## Entorno de desarrollo

- Flutter 3.47.4 estable, con Dart 3.13.3 incluido.
- VS Code con las extensiones Flutter y Dart.
- Android Studio 2026.1.4.7 y su JDK integrado.
- Android SDK API 36, Build Tools 36.0.0, Platform Tools, Command-line Tools, emulador, NDK 28.2.13676358 y CMake 3.22.1.
- Chrome o Edge para pruebas web.

Flutter está instalado en `C:\Users\gmedina\develop\flutter` y Android SDK en `C:\Users\gmedina\AppData\Local\Android\Sdk`. Estas herramientas quedan fuera del repositorio con autorización del usuario.

Cerrar y volver a abrir las terminales y VS Code después de la instalación para cargar el PATH actualizado.

## Primera prueba web

En PowerShell:

```powershell
Set-Location -LiteralPath 'C:\Users\gmedina\OneDrive - LEIVA HERMANOS S A\Proyectos Leiva\Leiva-App-Interna'
git rev-parse --show-toplevel
git branch --show-current
flutter pub get
flutter run -d chrome
```

La raíz debe coincidir con esa carpeta y la rama de trabajo debe ser `DEV`. También se puede usar `flutter run -d edge`.

## Primera prueba Android

```powershell
flutter emulators
flutter emulators --launch Leiva_API_36
flutter devices
flutter run -d emulator-5554
```

Usar el identificador que muestre `flutter devices` si difiere. También se puede conectar un teléfono con depuración USB habilitada y autorizar la PC desde el teléfono.

## Validación y compilación

```powershell
flutter doctor -v
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

La compilación web queda en `build/web`. El APK de pruebas queda en `build/app/outputs/flutter-apk/app-debug.apk`. El APK usa firma de depuración y no es una distribución de producción.

## Flujo de trabajo

`DEV` es la rama principal y de desarrollo. `TEST` es para validación y `PROD` para producción. Las promociones entre ramas se realizan cuando el usuario lo indique. Consultar `AGENTS.md` antes de modificar archivos.

## Conexión al portal

Antes de implementar la conexión necesitamos la URL del portal, documentación de su API si existe y el mecanismo de autenticación. No guardar contraseñas, tokens ni claves en el repositorio o en el código de la app.

## Referencias

- [Instalación de Flutter](https://docs.flutter.dev/install/manual)
- [Configuración Android](https://docs.flutter.dev/platform-integration/android/setup)

## Validación inicial (18/09/2026)

- `flutter doctor -v`: sin problemas; reconoce Android, Chrome y Edge.
- `flutter analyze`: sin errores.
- `flutter test`: prueba de interacción aprobada.
- `flutter build web`: compilación correcta y arranque probado en Chrome.
- `flutter build apk --debug`: compilación correcta; APK instalado en el emulador y contador verificado de 0 a 1.

El emulador `Leiva_API_36` usa Android 16, 4 GB de RAM, gráficos por software y resolución 720 × 1600 (densidad 280). El primer arranque mostró bloqueos de System UI; después del ajuste y reinicio se verificó la app. El arranque inicial y la primera compilación pueden ser lentos. La primera compilación Android tardó aproximadamente 8 minutos.
