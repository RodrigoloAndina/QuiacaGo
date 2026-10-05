# Desplegar eliminación de cuenta

1. Ejecutar `operations_and_privacy.sql` y después `pilot_integration.sql` en SQL Editor.
2. En Edge Functions crear la función `delete-account` con los dos archivos de esta carpeta: `index.ts` y `handler.mjs`.
3. Desplegar. Las variables `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` son variables del entorno de Supabase, nunca se agregan a la APK.

Alternativa desde la raíz del repositorio con Supabase CLI autenticado:

```powershell
supabase functions deploy delete-account --project-ref xxqumxhdpjtjdcnnjmdm
```

La función verifica la sesión contra Auth antes de reservar la cuenta. Sólo permite
eliminar al usuario autenticado. Bloquea viajes/reclamos abiertos. Elimina objetos
con Storage API, minimiza datos por RPC y finalmente elimina Auth. Si falla un paso,
devuelve error y admite reintentar; no presenta una baja parcial como completada.

Pruebas locales sin datos reales: `node --test tool/delete_account_test.mjs`.
Fuentes: https://supabase.com/docs/reference/javascript/auth-admin-deleteuser
y https://supabase.com/docs/reference/javascript/storage-from-remove
