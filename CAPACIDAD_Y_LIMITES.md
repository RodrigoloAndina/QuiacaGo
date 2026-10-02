# QuiacaGo: capacidad y límites del piloto

Actualizado: 2 de octubre de 2026.

## Servicios usados

- Supabase: autenticación, PostgreSQL, Realtime y almacenamiento de documentos.
- OpenStreetMap: mosaicos del mapa, sin API key.
- OSRM público: cálculo de rutas, sin API key.
- Google Fonts y unpkg: recursos visuales del panel web.
- WhatsApp/teléfono: se abren mediante enlaces del dispositivo; no se consume una API paga.

## Supabase Free

Límites publicados para el plan gratuito:

- Solicitudes API: ilimitadas, pero sujetas al CPU compartido y a las cuotas de transferencia.
- Base PostgreSQL: 500 MB antes de entrar en modo de sólo lectura.
- Transferencia: 5 GB mensuales y 5 GB de transferencia cacheada.
- Usuarios activos mensuales: 50.000.
- Storage: 1 GB.
- Realtime: 2 millones de mensajes mensuales, 200 conexiones simultáneas y 100 mensajes por segundo.
- Dos proyectos gratuitos; un proyecto puede pausarse tras una semana sin actividad.

Fuentes oficiales:

- https://supabase.com/docs/guides/platform/billing-on-supabase
- https://supabase.com/docs/guides/realtime/limits
- https://supabase.com/docs/guides/platform/database-size
- https://supabase.com/pricing

La `anon key` no posee una cantidad propia de usos. Está diseñada para estar en las aplicaciones; la seguridad depende de Auth, RLS y las funciones de base de datos. No debe confundirse con una `service_role`, que nunca debe incluirse en una APK o página pública.

## Estimación de viajes

No existe un número contractual de viajes porque cada viaje consume base, transferencia y CPU de forma diferente. Para este esquema, reservando entre 2 y 4 KB por viaje incluyendo índices, calificación y una eventual incidencia, 500 MB representan aproximadamente 125.000 a 250.000 viajes. Dejando margen operativo y espacio para perfiles, configuración y mantenimiento, se recomienda considerar **100.000 a 200.000 viajes históricos** como techo de almacenamiento del plan gratuito.

Ejemplos sin archivar datos:

| Promedio | Tiempo aproximado para 100.000–200.000 viajes |
|---|---:|
| 100 viajes/día | 2,7–5,5 años |
| 300 viajes/día | 11–22 meses |
| 500 viajes/día | 6–13 meses |
| 1.000 viajes/día | 3–7 meses |

En operación normal, el límite práctico puede aparecer antes por conexiones simultáneas, transferencia o capacidad del CPU Nano compartido. Con la reducción de sondeos aplicada en esta versión, el plan gratuito es razonable para un piloto de **20 a 30 conductores conectados y 100 a 300 viajes diarios**, siempre controlando el panel de Usage de Supabase. Esta cifra es una recomendación conservadora, no una garantía de servicio.

Conviene pasar a Pro antes de cualquiera de estos puntos:

- Más de 50 dispositivos conectados simultáneamente de manera sostenida.
- Más de 500 viajes diarios sostenidos.
- 70% de base, transferencia o mensajes Realtime consumidos.
- Necesidad de backups automáticos, soporte o disponibilidad de producción.

## Mapas OpenStreetMap

OpenStreetMap no exige API key ni publica una cuota numérica para `tile.openstreetmap.org`, pero es un servicio comunitario de capacidad limitada, sin SLA, y puede bloquear aplicaciones con uso pesado o incorrecto. Exige identificación, atribución visible y respeto de caché; esta versión ya muestra la atribución y usa identificadores propios.

Política oficial: https://operations.osmfoundation.org/policies/tiles/

Para un piloto local el servicio puede utilizarse con moderación. Para producción sostenida conviene contratar un proveedor de mosaicos OSM con cuota y SLA o alojar los mosaicos propios. No debe agregarse descarga masiva de mapas offline sobre el servidor comunitario.

## Rutas OSRM

`router.project-osrm.org` es un servidor de demostración gratuito. No tiene una API key ni una cuota contractual pública, pero es de mejor esfuerzo, no ofrece garantía de calidad o disponibilidad y el acceso puede retirarse. La aplicación posee una ruta visual de respaldo si OSRM falla, pero ese respaldo no equivale a navegación real.

Para producción se recomienda desplegar OSRM propio para la región o contratar un proveedor de rutas. Documentación del proyecto: https://github.com/Project-OSRM/osrm-backend

## Consumo optimizado en esta versión

- Ubicación del conductor: cada 10 segundos, dentro de la ventana activa de 20 segundos.
- Búsqueda de ofertas: cada 4 segundos, sin duplicar la publicación GPS.
- Métricas administrativas: cada 30 segundos en lugar de cada 5 segundos.
- El mapa administrativo deja de consultar ubicaciones al salir de su pestaña.
- Las cancelaciones son transacciones atómicas y no se confirman localmente si falta conexión.

## Seguimiento recomendado

Revisar semanalmente en Supabase: Database Size, Egress, Realtime Messages, Peak Connections y Storage. Durante el piloto conviene guardar además el máximo de conductores conectados, viajes por hora y latencia de aceptación. Con datos reales de dos a cuatro semanas se puede reemplazar esta estimación por una proyección precisa.

## Distribución de las aplicaciones

- Instalar los APK directamente para pruebas no agrega un costo de plataforma.
- La distribución Android completa requiere actualmente una cuenta con pago único de USD 25; la modalidad limitada gratuita admite hasta 20 dispositivos.
- Si más adelante se crea una versión iOS, Apple Developer cuesta actualmente USD 99 por año. Organismos gubernamentales y algunas entidades pueden solicitar una exención.

Fuentes oficiales:

- https://support.google.com/android-developer-console/answer/16604405
- https://developer.apple.com/programs/whats-included/
