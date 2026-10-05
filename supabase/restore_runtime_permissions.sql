-- Restaura permisos de las RPC que consumen las apps y el panel.
-- Ejecutar después de production_hardening.sql y operations_and_privacy.sql.
begin;

revoke all on function public.check_app_release(text,integer) from public;
grant execute on function public.check_app_release(text,integer) to anon,authenticated;

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array[
      'create_trip','get_driver_trip_offer','accept_trip','decline_trip_offer',
      'mark_arrived','verify_start_code','request_finish_code','verify_finish_code',
      'acknowledge_cash_payment','confirm_cash_payment','cancel_trip','rate_trip',
      'get_my_trip_codes','available_driver_count','refresh_driver_compliance',
      'get_my_legal_acceptance','accept_legal_documents','get_public_support_config',
      'mark_driver_message_read','confirm_my_phone_verification',
      'get_my_open_payment_dispute','report_cash_payment_not_received',
      'get_my_payment_disputes','get_payment_dispute_messages',
      'add_payment_dispute_message','get_my_driver_stats','request_my_account_deletion',
      'review_driver','review_driver_and_notify','send_driver_message',
      'admin_update_driver_record','admin_set_account_suspension',
      'admin_list_users','admin_recent_cancellations','admin_list_payment_disputes',
      'admin_operations_summary','resolve_payment_dispute','set_fare_settings'
    ])
  loop
    execute format('revoke all on function %s from public,anon',f.signature);
    execute format('grant execute on function %s to authenticated',f.signature);
  end loop;
end $$;

-- Permanecen exclusivos de service_role para la Edge Function de baja.
revoke all on function public.account_deletion_objects(uuid),
 public.finish_account_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_objects(uuid),
 public.finish_account_data_deletion(uuid) to service_role;

commit;

select 'check_app_release para APK sin sesión' componente,
 case when has_function_privilege('anon','public.check_app_release(text,integer)','EXECUTE')
 then 'OK' else 'FALTA' end estado
union all
select 'create_trip para usuario autenticado',
 case when has_function_privilege('authenticated','public.create_trip(text,text,text,double precision,double precision,text,double precision,double precision,double precision)','EXECUTE')
 then 'OK' else 'FALTA' end
union all
select 'get_driver_trip_offer para conductor',
 case when has_function_privilege('authenticated','public.get_driver_trip_offer()','EXECUTE')
 then 'OK' else 'FALTA' end
union all
select 'funciones de borrado sólo service_role',
 case when has_function_privilege('service_role','public.finish_account_data_deletion(uuid)','EXECUTE')
  and not has_function_privilege('authenticated','public.finish_account_data_deletion(uuid)','EXECUTE')
 then 'OK' else 'FALTA' end;
