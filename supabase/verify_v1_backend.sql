-- Verificación de sólo lectura. Ejecutar después de registration_flow.sql.
select 'passenger_private_data' as componente,
       case when to_regclass('public.passenger_private_data') is not null
            then 'OK' else 'FALTA' end as estado
union all
select 'driver_documents.expires_at',
       case when exists(
         select 1 from information_schema.columns
         where table_schema='public' and table_name='driver_documents'
           and column_name='expires_at'
       ) then 'OK' else 'FALTA' end
union all
select 'review_driver(uuid,boolean,integer)',
       case when to_regprocedure('public.review_driver(uuid,boolean,integer)') is not null
            then 'OK' else 'FALTA' end
union all
select 'get_driver_trip_offer()',
       case when to_regprocedure('public.get_driver_trip_offer()') is not null
            then 'OK' else 'FALTA' end
union all
select 'perfil privado por RLS',
       case when exists(
         select 1 from pg_policies where schemaname='public'
          and tablename='profiles' and policyname='profiles_read_self_or_admin'
       ) then 'OK' else 'FALTA' end
union all
select 'actualización segura de documentos',
       case when exists(
         select 1 from pg_policies where schemaname='storage'
          and tablename='objects' and policyname='driver_documents_update'
       ) then 'OK' else 'FALTA' end
union all
select 'fare_settings',
       case when to_regclass('public.fare_settings') is not null
            then 'OK' else 'FALTA' end
union all
select 'set_fare_settings(numeric,numeric)',
       case when to_regprocedure('public.set_fare_settings(numeric,numeric)') is not null
            then 'OK' else 'FALTA' end
union all
select 'tarifa obligatoria al crear viaje',
       case when exists(
         select 1 from pg_trigger
         where tgname='apply_current_fare_trigger' and not tgisinternal
       ) then 'OK' else 'FALTA' end
union all
select 'trip_ratings',
       case when to_regclass('public.trip_ratings') is not null
            then 'OK' else 'FALTA' end
union all
select 'rate_trip(text,integer,text)',
       case when to_regprocedure('public.rate_trip(text,integer,text)') is not null
            then 'OK' else 'FALTA' end
union all
select 'admin_notifications',
       case when to_regclass('public.admin_notifications') is not null
            then 'OK' else 'FALTA' end
union all
select 'admin_update_driver_record(...)',
       case when exists(
         select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='admin_update_driver_record'
       ) then 'OK' else 'FALTA' end
union all
select 'avisos automáticos de conductores',
       case when exists(
         select 1 from pg_trigger
         where tgname='notify_admins_driver_profile' and not tgisinternal
       ) then 'OK' else 'FALTA' end;
