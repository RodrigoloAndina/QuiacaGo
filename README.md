# QuiacaGo

Sistema de movilidad para La Quiaca: aplicaciones de conductor y pasajero,
panel municipal y backend en Supabase.

La guía completa del entorno y la arquitectura está en
[`GUIA_DESARROLLO.md`](GUIA_DESARROLLO.md).

## Orden de actualización de Supabase

Después de los scripts base ya existentes, ejecutar en Supabase SQL Editor:

1. `supabase/cancellation_management.sql` para habilitar cancelaciones, incidencias, reasignaciones y suspensiones temporales.
2. `supabase/admin_driver_notifications.sql` para habilitar la bandeja de avisos y la edición administrativa de legajos.
3. `supabase/driver_messages_and_phone_verification.sql` para mensajes al conductor y verificación OTP del celular.
4. `supabase/app_release_control.sql` para vencimiento, apagado remoto y versión mínima de los APK.
5. `supabase/production_hardening.sql` al final para consentimiento legal, cobro
   confirmado por el conductor, códigos privados, RLS de ubicaciones y límites
   de documentos. Luego ejecutar `supabase/verify_v1_backend.sql`.

Para la verificación real por código hay que habilitar Phone Auth en Supabase y conectar un proveedor SMS/WhatsApp (Twilio, MessageBird o Vonage). Sin ese proveedor la pantalla queda preparada, pero no puede enviarse ningún código.

La estimación del piloto y los límites de los servicios están documentados en `CAPACIDAD_Y_LIMITES.md`.

Los APK de prueba se generan con
`.\tool\build_android_apps.ps1 -Channel beta`. Su habilitación, vencimiento,
mensaje y compilación mínima se administran desde la tabla
`app_release_controls` de Supabase.
