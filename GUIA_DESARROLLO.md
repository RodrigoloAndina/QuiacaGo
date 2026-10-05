# Guía de desarrollo de QuiacaGo

## Estado del entorno local

El repositorio está preparado en `E:\QuiacaGO` y usa estas herramientas:

- Flutter 3.47.6 / Dart 3.13.5: `E:\DevTools\flutter`
- Java Temurin 17: `E:\DevTools\jdk-17`
- Android SDK: `E:\DevTools\Android`
- Android API de compilación: 36
- Android mínimo: API 24 (Android 7.0)
- Android objetivo: API 34
- Android NDK: 28.2.13676358
- Gradle 9.3.1, Android Gradle Plugin 9.1.0 y Kotlin 2.4.0

Las rutas se agregaron a las variables del usuario. Hay que reiniciar las
terminales o editores que estuvieran abiertos antes de la instalación.

## Qué contiene el repositorio

QuiacaGo es un único proyecto Flutter con tres puntos de entrada:

| Variante | Punto de entrada | Función |
| --- | --- | --- |
| Conductor | `lib/main.dart` | Conexión del taxi, ofertas, viaje, ganancias, perfil y documentación |
| Pasajero | `lib/main_pasajero.dart` | Registro, solicitud, seguimiento, pago y calificación |
| Administración | `lib/main_admin.dart` | Aprobación y gestión municipal de conductores |

También existen dos recursos auxiliares:

- `admin_web/index.html`: panel web estático.
- `server.js`: servidor local de demostración con datos en memoria. No es el
  backend productivo de las aplicaciones Flutter.

Las aplicaciones móviles son sabores Android independientes y pueden convivir
en el mismo teléfono:

| Sabor | Identificador Android | Nombre instalado |
| --- | --- | --- |
| `conductor` | `com.quiacago.conductor` | QuiacaGo Conductor |
| `pasajero` | `com.quiacago.pasajero` | QuiacaGo Pasajero |

Cada sabor tiene su propio ícono y pantalla de arranque. Los originales de
marca están en `assets/branding`; los tamaños Android están bajo
`android/app/src/conductor/res` y `android/app/src/pasajero/res`.

## Arquitectura

- Interfaz: Flutter Material 3.
- Estado: Riverpod para proveedores y estado compartido; varias pantallas
  mantienen estado local con `StatefulWidget`.
- Navegación: `go_router`.
- Backend real: Supabase Auth, PostgreSQL, Storage y Realtime.
- Mapas: OpenStreetMap mediante `flutter_map`.
- Rutas: servidor público de OSRM, con una representación visual de respaldo.
- Ubicación: `geolocator`, más un servicio Android en primer plano para el
  conductor.
- Persistencia sin conexión: archivos JSON locales para el viaje activo y
  acciones pendientes compatibles.

Las capas principales son:

- `lib/features`: pantallas y flujos de usuario.
- `lib/services`: Supabase, viajes, ubicación, seguimiento, documentos,
  tarifas, autenticación y sincronización.
- `lib/repositories`: contratos y acceso a datos usado por los proveedores.
- `lib/providers`: estado Riverpod.
- `lib/models`: modelos de dominio.
- `supabase`: esquema, funciones SQL, políticas RLS y migraciones.

## Flujo de un viaje

1. El pasajero inicia sesión y solicita un viaje mediante la función SQL
   `create_trip`.
2. Supabase crea el viaje, calcula la tarifa vigente y genera los códigos de
   seguridad.
3. El despachador del backend ofrece el viaje a un conductor disponible.
4. El conductor consulta `get_driver_trip_offer` y acepta mediante
   `accept_trip`.
5. El pasajero recibe cambios del viaje por Supabase Realtime y sigue la
   ubicación del conductor.
6. El conductor marca llegada; el pasajero entrega el código de inicio.
7. Al llegar al destino se valida el código de finalización y se confirma el
   pago en efectivo.
8. El viaje queda completado y puede recibir una calificación.

Las cancelaciones se resuelven en el servidor de forma atómica. La aplicación
no confirma una cancelación sin conexión. La confirmación de pago sí puede
quedar en cola local y sincronizarse al recuperar Internet.

## Backend y seguridad

`lib/services/supabase_service.dart` contiene la URL y la clave pública de
Supabase. Una clave `anon` o publicable puede distribuirse en el APK; la
seguridad real depende de las políticas RLS y de las funciones SQL. Nunca se
debe incorporar una clave `service_role` en este repositorio.

Para una base nueva, revisar `supabase/schema.sql` como esquema canónico. En
una base existente no se debe volver a ejecutar todo el esquema a ciegas:
aplicar las migraciones incrementales en el orden documentado en `README.md`
y validar al final con `supabase/verify_v1_backend.sql`.

La verificación telefónica real requiere habilitar Phone Auth en Supabase y
configurar un proveedor de SMS o WhatsApp.

## Comandos habituales

Desde `E:\QuiacaGO`:

```powershell
flutter pub get
flutter analyze
flutter test
```

Ejecutar cada variante en un dispositivo o emulador:

```powershell
flutter run --flavor conductorBeta --target lib/main.dart
flutter run --flavor pasajeroBeta --target lib/main_pasajero.dart
```

Generar APK de depuración:

```powershell
flutter build apk --debug --flavor conductorBeta --target lib/main.dart
flutter build apk --debug --flavor pasajeroBeta --target lib/main_pasajero.dart
```

Los APK resultantes se generan con nombres separados bajo
`build/app/outputs/flutter-apk`.

Para validar y construir las dos aplicaciones con un solo comando:

```powershell
.\tool\build_android_apps.ps1 -Channel beta
```

El panel municipal web se inicia con:

```powershell
node server.js
```

Después queda disponible en `http://localhost:3000/admin`. Consulta los datos
de Supabase y requiere una cuenta cuyo perfil tenga el rol `admin`.

También existe una versión Flutter del panel:

```powershell
flutter run -d chrome --target lib/main_admin.dart
```

## Vencimiento y apagado remoto de APK

Ejecutar `supabase/app_release_control.sql` una vez. Después, desde Supabase
Table Editor > `app_release_controls`, se pueden modificar:

- `enabled`: en `false` bloquea la aplicación.
- `expires_at`: fecha y hora de vencimiento calculada por el servidor.
- `minimum_build`: obliga a instalar una compilación igual o superior.
- `message`: explicación que verá la persona usuaria.
- `update_url`: enlace opcional para descargar la versión vigente.

Ejemplos desde Supabase SQL Editor:

```sql
-- Extender la prueba del conductor hasta una fecha argentina.
update public.app_release_controls
set expires_at='2026-11-01 23:59:00-03', enabled=true
where app_key='conductor_beta';

-- Apagar inmediatamente las dos aplicaciones beta.
update public.app_release_controls
set enabled=false
where app_key in ('conductor_beta','pasajero_beta');

-- Obligar a instalar una compilación posterior.
update public.app_release_controls
set minimum_build=2
where app_key='pasajero_beta';
```

Las aplicaciones beta se identifican como `conductor_beta` y
`pasajero_beta`; se verifican al iniciar, al volver al primer plano y cada cinco
minutos. Si no pueden comunicarse con Supabase, quedan bloqueadas hasta poder
validarse. Producción continúa funcionando ante una caída temporal del control
remoto para no interrumpir el servicio.

Los identificadores Android son diferentes y permiten instalar prueba y
producción en el mismo teléfono:

- `com.quiacago.conductor.beta` / `com.quiacago.pasajero.beta`
- `com.quiacago.conductor` / `com.quiacago.pasajero`

Para conectar una compilación con otro proyecto Supabase:

```powershell
flutter build apk --debug --flavor conductorBeta --target lib/main.dart `
  --dart-define=SUPABASE_URL=https://PROYECTO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=CLAVE_PUBLICA
```

La clave debe ser la pública (`publishable`/`anon`), nunca `service_role`.

## Validación realizada

- `flutter doctor -v`: sin problemas.
- `flutter analyze`: sin errores ni advertencias.
- `flutter test`: 15 pruebas aprobadas.
- APK de Conductor: compilación de depuración aprobada.
- APK de Pasajero: compilación de depuración aprobada.

No se realizaron pruebas destructivas ni de integración con cuentas reales, GPS físico,
notificaciones SMS ni datos productivos de Supabase. Esas verificaciones
requieren un teléfono Android y usuarios de prueba para pasajero, conductor y
administrador.

## Trabajo recomendado a continuación

1. Añadir pruebas de integración del ciclo completo de viaje.
2. Separar la configuración de Supabase por desarrollo, prueba y producción.
3. Crear claves de firma de publicación y configurar Google Play para cada app.
4. Migrar el proyecto y sus complementos a Kotlin integrado antes de que una
   futura versión de Flutter retire la compatibilidad antigua.
5. Sustituir los servicios públicos de mosaicos y rutas por proveedores con
   cuota y SLA antes de una operación sostenida.
