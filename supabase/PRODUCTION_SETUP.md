# Activación de las funciones de producción

Estos cambios todavía no afectan la base remota hasta ejecutarlos en el SQL
Editor de Supabase. Para una base ya existente, ejecutá los archivos en este
orden:

1. `compatibility_patch.sql` (si la instalación antigua tiene fechas como texto)
2. `migrate_existing.sql`
3. `registration_flow.sql`
4. `driver_messages_and_phone_verification.sql`
5. `admin_driver_notifications.sql`
6. `ratings.sql`
7. `tariff_settings.sql`
8. `app_release_control.sql`
9. `payment_disputes.sql`
10. `production_functionality.sql`
11. `complete_trip_flow.sql`
12. `cancellation_management.sql`
13. `production_hardening.sql`
14. `operations_and_privacy.sql`
15. `pilot_integration.sql`
16. `restore_runtime_permissions.sql`
17. `restore_driver_document_permissions.sql`
18. `verify_v1_backend.sql`

Además del SQL, desplegar `functions/delete-account` siguiendo su README.
Los controles SQL no comprueban que una Edge Function esté desplegada.

El último archivo es de solo lectura. Todas sus filas deben devolver `OK`.

`operations_and_privacy.sql` debe ejecutarse después de `production_hardening.sql`
porque utiliza `passenger_paid_at` y las funciones de pago protegidas.

Después de aplicar los scripts, cambiá `support_phone` en `system_settings` por
el número real de soporte en formato internacional. `emergency_phone` queda en
`911`, pero también puede administrarse desde esa tabla.

Antes del primer viaje, reemplazá los datos pendientes de responsable, domicilio,
correo y teléfono en la compilación con `--dart-define=LEGAL_OPERATOR=...`,
`LEGAL_ADDRESS`, `LEGAL_EMAIL` y `LEGAL_PHONE`. La aceptación se guarda en
`legal_consents`; una nueva versión bloquea nuevas solicitudes hasta aceptarla.

Los servicios persistentes de Android usan una notificación visible, tal como
exige Android: el conductor la ve mientras está disponible y el pasajero
mientras posee un viaje activo.

Para cuentas de prueba, después de aplicar el backend, ejecutá desde PowerShell
`.\supabase\create_test_users.ps1 -Create`. El script pide de forma oculta una
clave secreta de administración, la usa solamente durante esa ejecución y no la
guarda. Los conductores quedan pendientes de aprobación documental.
