-- Tarifas oficiales administrables. Ejecutar una vez en Supabase SQL Editor.
begin;

create table if not exists public.fare_settings (
  id text primary key check (id = 'current'),
  day_amount numeric(10,2) not null check (day_amount > 0),
  night_amount numeric(10,2) not null check (night_amount > 0),
  day_starts_at time not null default time '06:00',
  night_starts_at time not null default time '22:00',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.fare_settings(
  id,day_amount,night_amount,day_starts_at,night_starts_at
) values ('current',2500,2500,time '06:00',time '22:00')
on conflict(id) do nothing;

alter table public.fare_settings enable row level security;
drop policy if exists fare_settings_read on public.fare_settings;
create policy fare_settings_read on public.fare_settings for select
to authenticated using(true);
drop policy if exists fare_settings_admin_update on public.fare_settings;
create policy fare_settings_admin_update on public.fare_settings for update
to authenticated using(public.is_admin()) with check(public.is_admin());

create or replace function public.set_fare_settings(
  p_day_amount numeric,
  p_night_amount numeric
) returns public.fare_settings
language plpgsql security definer set search_path=public as $$
declare result public.fare_settings;
begin
  if not public.is_admin() then
    raise exception 'Sólo un administrador puede modificar las tarifas';
  end if;
  if p_day_amount <= 0 or p_night_amount <= 0 then
    raise exception 'Las tarifas deben ser mayores que cero';
  end if;
  update public.fare_settings set
    day_amount=p_day_amount,
    night_amount=p_night_amount,
    updated_at=now(),
    updated_by=auth.uid()
  where id='current'
  returning * into result;
  return result;
end $$;

revoke execute on function public.set_fare_settings(numeric,numeric)
from public,anon;
grant execute on function public.set_fare_settings(numeric,numeric)
to authenticated;

-- El importe final se determina siempre en el servidor. Esto evita que una
-- app desactualizada o alterada cree viajes con una tarifa distinta.
create or replace function public.apply_current_fare() returns trigger
language plpgsql security definer set search_path=public as $$
declare
  settings public.fare_settings;
  local_time time := clock_timestamp() at time zone 'America/Argentina/Jujuy';
begin
  select * into settings from public.fare_settings where id='current';
  if settings.day_starts_at < settings.night_starts_at then
    new.fare_amount := case
      when local_time >= settings.day_starts_at
       and local_time < settings.night_starts_at
      then settings.day_amount else settings.night_amount end;
  else
    new.fare_amount := case
      when local_time >= settings.day_starts_at
        or local_time < settings.night_starts_at
      then settings.day_amount else settings.night_amount end;
  end if;
  return new;
end $$;

drop trigger if exists apply_current_fare_trigger on public.trips;
create trigger apply_current_fare_trigger before insert on public.trips
for each row execute function public.apply_current_fare();

commit;
