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
       ) then 'OK' else 'FALTA' end
union all
select 'app_release_controls',
       case when to_regclass('public.app_release_controls') is not null
            then 'OK' else 'FALTA' end
union all
select 'check_app_release(text,integer)',
       case when to_regprocedure('public.check_app_release(text,integer)') is not null
            then 'OK' else 'FALTA' end
union all
select 'driver_is_operational(uuid)',
       case when to_regprocedure('public.driver_is_operational(uuid)') is not null
            then 'OK' else 'FALTA' end
union all
select 'refresh_driver_compliance(uuid,boolean)',
       case when to_regprocedure('public.refresh_driver_compliance(uuid,boolean)') is not null
            then 'OK' else 'FALTA' end
union all
select 'bloqueo servidor de conductor inhabilitado',
       case when exists(
         select 1 from pg_trigger
         where tgname='guard_trip_driver_eligibility' and not tgisinternal
       ) then 'OK' else 'FALTA' end
union all
select 'delete_my_account()',
       case when to_regprocedure('public.delete_my_account()') is not null
            then 'OK' else 'FALTA' end
union all
select 'get_public_support_config()',
       case when to_regprocedure('public.get_public_support_config()') is not null
            then 'OK' else 'FALTA' end
union all
select 'driver_documents.review_note',
       case when exists(
         select 1 from information_schema.columns
         where table_schema='public' and table_name='driver_documents'
           and column_name='review_note'
       ) then 'OK' else 'FALTA' end
union all
select 'payment_disputes',
       case when to_regclass('public.payment_disputes') is not null
            then 'OK' else 'FALTA' end
union all
select 'report_cash_payment_not_received(text,text,text)',
       case when to_regprocedure('public.report_cash_payment_not_received(text,text,text)') is not null
            then 'OK' else 'FALTA' end
union all
select 'resolve_payment_dispute(uuid,text,text)',
       case when to_regprocedure('public.resolve_payment_dispute(uuid,text,text)') is not null
            then 'OK' else 'FALTA' end;

-- Integración móvil: comprobar también las RPC nuevas. La existencia de estas
-- funciones NO prueba el despliegue de Edge Functions ni un viaje completo.
select signature as componente,
 case when to_regprocedure('public.' || signature) is not null then 'OK' else 'FALTA' end as estado
from (values ('get_my_trip_codes(text)'), ('available_driver_count()'),
 ('acknowledge_cash_payment(text)'), ('confirm_cash_payment(text)'),
 ('request_my_account_deletion()'), ('account_deletion_objects(uuid)'),
 ('finish_account_data_deletion(uuid)'), ('get_my_legal_acceptance()'),
 ('accept_legal_documents(text)')) checks(signature);
