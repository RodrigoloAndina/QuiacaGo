-- Aplicar después de operations_and_privacy.sql. Reejecutable.
begin;
-- Conservar viajes de la contraparte al desvincular la cuenta eliminada.
alter table public.trips alter column passenger_id drop not null;
create or replace function public.available_driver_count() returns integer
language sql stable security definer set search_path=public as $$
 select count(*)::integer from public.driver_locations dl
 join public.profiles p on p.id::text=dl.driver_id
 where auth.uid() is not null and dl.is_online
 and dl.updated_at>now()-interval '45 seconds'
 and public.account_is_enabled(p.id) and public.driver_is_operational(p.id)
 and public.has_current_legal_consent(p.id)
 and not exists(select 1 from public.trips t where t.driver_id=dl.driver_id
 and t.status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending'))
$$;
revoke all on function public.available_driver_count() from public,anon;
grant execute on function public.available_driver_count() to authenticated;
commit;
