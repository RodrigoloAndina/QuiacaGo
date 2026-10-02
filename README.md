# quiaca_go_conductor

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# QuiacaGo

## Orden de actualización de Supabase

Después de los scripts base ya existentes, ejecutar en Supabase SQL Editor:

1. `supabase/cancellation_management.sql` para habilitar cancelaciones, incidencias, reasignaciones y suspensiones temporales.
2. `supabase/admin_driver_notifications.sql` para habilitar la bandeja de avisos y la edición administrativa de legajos.
3. `supabase/driver_messages_and_phone_verification.sql` para mensajes al conductor y verificación OTP del celular.

Para la verificación real por código hay que habilitar Phone Auth en Supabase y conectar un proveedor SMS/WhatsApp (Twilio, MessageBird o Vonage). Sin ese proveedor la pantalla queda preparada, pero no puede enviarse ningún código.

La estimación del piloto y los límites de los servicios están documentados en `CAPACIDAD_Y_LIMITES.md`.
