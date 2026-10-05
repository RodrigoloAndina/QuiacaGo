-- QuiacaGo - cancelaciones, incidencias y suspensiones temporales.
-- Ejecutar una vez en Supabase SQL Editor después de complete_trip_flow.sql.
begin;

alter table public.profiles
  add column if not exists account_suspended_until timestamptz,
  add column if not exists account_suspension_reason text,
  add column if not exists account_suspended_at timestamptz,
  add column if not exists account_suspended_by uuid;

alter table public.trips
  add column if not exists arrived_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by uuid;

create table if not exists public.trip_cancellation_events (
  id uuid primary key default gen_random_uuid(),
  trip_id text not null,
  actor_id uuid not null references public.profiles(id),
  actor_role text not null check (actor_role in ('passenger','driver','admin','system')),
  affected_user_id uuid references public.profiles(id),
  previous_status text not null,
  outcome text not null check (outcome in ('cancelled','reassigned','no_show')),
  reason_code text not null,
  reason_detail text,
  created_at timestamptz not null default now()
);

create index if not exists cancellation_events_actor_date_idx
  on public.trip_cancellation_events(actor_id,created_at desc);
create index if not exists cancellation_events_trip_idx
  on public.trip_cancellation_events(trip_id,created_at desc);
create index if not exists profiles_suspension_idx
  on public.profiles(account_suspended_until)
  where account_suspended_until is not null;

alter table public.trip_cancellation_events enable row level security;
drop policy if exists cancellation_events_admin_read on public.trip_cancellation_events;
drop policy if exists cancellation_events_participant_read on public.trip_cancellation_events;
create policy cancellation_events_admin_read on public.trip_cancellation_events
  for select to authenticated using(public.is_admin());
create policy cancellation_events_participant_read on public.trip_cancellation_events
  for select to authenticated using(actor_id=auth.uid() or affected_user_id=auth.uid());

create or replace function public.account_is_enabled(p_user_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce((select account_suspended_until is null
                     or account_suspended_until<=now()
                   from public.profiles where id=p_user_id),false)
$$;

drop policy if exists trips_create on public.trips;
create policy trips_create on public.trips for insert to authenticated
  with check(passenger_id=auth.uid() and driver_id is null
    and status='requested' and public.account_is_enabled(auth.uid())
    and not public.passenger_has_open_payment_dispute(auth.uid()));

create or replace function public.create_trip(
 p_passenger_name text,p_passenger_phone text,p_pickup_address text,
 p_pickup_lat double precision,p_pickup_lng double precision,
 p_destination_address text,p_destination_lat double precision,
 p_destination_lng double precision,p_fare_amount double precision)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips;
begin
 if auth.uid() is null or not exists(
   select 1 from public.profiles where id=auth.uid() and role='passenger'
 ) then raise exception 'La sesión no pertenece a un pasajero registrado'; end if;
 if not public.account_is_enabled(auth.uid()) then
   raise exception 'La cuenta está suspendida temporalmente';
 end if;
 if public.passenger_has_open_payment_dispute(auth.uid()) then
   raise exception 'Tenés un reclamo de pago pendiente. Contactá a soporte para resolverlo';
 end if;
 update public.trips set status='cancelled',
   cancellation_reason='Reemplazada por una nueva solicitud',
   cancelled_at=now(),cancelled_by=auth.uid()
 where passenger_id=auth.uid() and status in ('requested','buscando','pending')
   and nullif(btrim(driver_id::text),'') is null;
 insert into public.trips(passenger_id,passenger_name,passenger_phone,driver_id,
   pickup_address,pickup_lat,pickup_lng,destination_address,destination_lat,
   destination_lng,fare_amount,pin_code,status)
 values(auth.uid(),p_passenger_name,p_passenger_phone,null,p_pickup_address,
   p_pickup_lat,p_pickup_lng,p_destination_address,p_destination_lat,
   p_destination_lng,p_fare_amount,'0000','requested') returning * into result;
 return result;
end $$;
grant execute on function public.create_trip(text,text,text,double precision,
  double precision,text,double precision,double precision,double precision)
  to authenticated;

create or replace function public.accept_trip(
 p_trip_id text,p_driver_name text,p_vehicle_info text)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips;
begin
 if auth.uid() is null then raise exception 'Sesión de conductor vencida'; end if;
 if not public.account_is_enabled(auth.uid()) then
   raise exception 'La cuenta está suspendida temporalmente';
 end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and role='driver') then
   raise exception 'La cuenta no tiene rol driver';
 end if;
 perform public.refresh_driver_compliance(auth.uid(),true);
 if not public.driver_is_operational(auth.uid()) then
   raise exception 'Conductor no habilitado: revisá aprobación y documentación';
 end if;
 update public.trips set driver_id=auth.uid()::text,driver_name=p_driver_name,
   vehicle_info=p_vehicle_info,status='accepted',accepted_at=now(),
   offered_driver_id=null,offer_expires_at=null
 where id::text=p_trip_id and status='requested'
   and nullif(btrim(driver_id::text),'') is null
   and offered_driver_id=auth.uid()::text and offer_expires_at>clock_timestamp()
 returning * into result;
 if result.id is null then raise exception 'El viaje ya no está disponible'; end if;
 return result;
end $$;
grant execute on function public.accept_trip(text,text,text) to authenticated;

-- Único punto de entrada para cancelar. El servidor decide según el actor y
-- el estado actual, evitando carreras y cancelaciones tardías sin conexión.
create or replace function public.cancel_trip(
  p_trip_id text,
  p_reason_code text,
  p_reason_detail text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_trip public.trips%rowtype;
  v_role text;
  v_outcome text;
  v_affected uuid;
begin
  if auth.uid() is null then raise exception 'Sesión vencida'; end if;
  if nullif(btrim(p_reason_code),'') is null then
    raise exception 'Seleccioná un motivo de cancelación';
  end if;

  select role::text into v_role from public.profiles where id=auth.uid();
  select * into v_trip from public.trips where id::text=p_trip_id for update;
  if v_trip.id is null then raise exception 'Viaje inexistente'; end if;

  if v_role='passenger' and v_trip.passenger_id::text=auth.uid()::text then
    if v_trip.status::text not in ('requested','accepted','arrived') then
      raise exception 'El viaje ya comenzó y no admite una cancelación normal';
    end if;
    v_outcome := 'cancelled';
    if nullif(v_trip.driver_id::text,'') is not null then
      v_affected := v_trip.driver_id::text::uuid;
    end if;
    update public.trips set status='cancelled',
      cancellation_reason=p_reason_code||coalesce(': '||nullif(btrim(p_reason_detail),''),''),
      cancelled_at=now(),cancelled_by=auth.uid(),
      offered_driver_id=null,offer_started_at=null,offer_expires_at=null
    where id=v_trip.id;

  elsif v_role='driver' and v_trip.driver_id::text=auth.uid()::text then
    if v_trip.status::text='accepted' then
      v_outcome := 'reassigned';
      v_affected := v_trip.passenger_id;
      update public.trips set status='requested',driver_id=null,driver_name=null,
        vehicle_info=null,accepted_at=null,arrived_at=null,
        offered_driver_id=null,offer_started_at=null,offer_expires_at=null
      where id=v_trip.id;
    elsif v_trip.status::text='arrived' then
      v_affected := v_trip.passenger_id;
      if p_reason_code='passenger_no_show' then
        if now()<coalesce(v_trip.arrived_at,v_trip.accepted_at,now())+interval '5 minutes' then
          raise exception 'Deben transcurrir 5 minutos desde la llegada';
        end if;
        v_outcome := 'no_show';
        update public.trips set status='cancelled',
          cancellation_reason='passenger_no_show',cancelled_at=now(),
          cancelled_by=auth.uid(),offered_driver_id=null,
          offer_started_at=null,offer_expires_at=null
        where id=v_trip.id;
      else
        v_outcome := 'reassigned';
        update public.trips set status='requested',driver_id=null,driver_name=null,
          vehicle_info=null,accepted_at=null,arrived_at=null,
          offered_driver_id=null,offer_started_at=null,offer_expires_at=null
        where id=v_trip.id;
      end if;
    else
      raise exception 'El viaje ya comenzó y no admite una cancelación normal';
    end if;
  else
    raise exception 'No tenés permiso para cancelar este viaje';
  end if;

  insert into public.trip_cancellation_events(
    trip_id,actor_id,actor_role,affected_user_id,previous_status,outcome,
    reason_code,reason_detail)
  values(v_trip.id::text,auth.uid(),v_role,v_affected,v_trip.status::text,
    v_outcome,p_reason_code,nullif(btrim(p_reason_detail),''));

  return jsonb_build_object(
    'success',true,
    'outcome',v_outcome,
    'message',case v_outcome
      when 'reassigned' then 'El pasajero seguirá buscando otro conductor.'
      when 'no_show' then 'El viaje fue cerrado por pasajero ausente.'
      else 'El viaje fue cancelado.' end);
end $$;
grant execute on function public.cancel_trip(text,text,text) to authenticated;

create or replace function public.mark_arrived(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='arrived',arrived_at=now(),
   code_expires_at=now()+interval '30 minutes'
 where id::text=p_trip_id and driver_id::text=auth.uid()::text and status='accepted';
 return found;
end $$;

-- Suspensión general para pasajeros o conductores. No interrumpe un viaje ya
-- iniciado; bloquea nuevos accesos, solicitudes y ofertas.
create or replace function public.admin_set_account_suspension(
  p_user_id uuid,p_days integer,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
  if not exists(select 1 from public.profiles where id=p_user_id) then
    raise exception 'Usuario inexistente';
  end if;
  if p_days>0 and nullif(btrim(p_reason),'') is null then
    raise exception 'El motivo es obligatorio';
  end if;

  update public.profiles set
    account_suspended_until=case when p_days>0
      then now()+(least(p_days,365)||' days')::interval else null end,
    account_suspension_reason=case when p_days>0 then btrim(p_reason) else null end,
    account_suspended_at=case when p_days>0 then now() else null end,
    account_suspended_by=case when p_days>0 then auth.uid() else null end,
    updated_at=now()
  where id=p_user_id;

  if p_days>0 then
    update public.driver_locations set is_online=false
      where driver_id::text=p_user_id::text;
    update public.trips set offered_driver_id=null,offer_started_at=null,
      offer_expires_at=null
      where offered_driver_id=p_user_id::text and status='requested';
  end if;
end $$;
grant execute on function public.admin_set_account_suspension(uuid,integer,text) to authenticated;

create or replace function public.admin_list_users()
returns table(
  id uuid,full_name text,phone text,email text,role text,created_at timestamptz,
  is_approved boolean,approved_until timestamptz,
  account_suspended_until timestamptz,account_suspension_reason text,
  trips_total bigint,trips_completed bigint,cancellations_total bigint,
  cancellations_30d bigint,last_cancellation_at timestamptz)
language sql stable security definer set search_path=public as $$
  select p.id,p.full_name,p.phone,p.email,p.role::text,p.created_at,
    p.is_approved,p.approved_until,p.account_suspended_until,
    p.account_suspension_reason,
    count(distinct t.id)::bigint,
    count(distinct t.id) filter(where t.status::text='completed')::bigint,
    count(distinct c.id)::bigint,
    count(distinct c.id) filter(where c.created_at>=now()-interval '30 days')::bigint,
    max(c.created_at)
  from public.profiles p
  left join public.trips t on t.passenger_id::text=p.id::text
    or t.driver_id::text=p.id::text
  left join public.trip_cancellation_events c on c.actor_id=p.id
  where public.is_admin()
  group by p.id,p.full_name,p.phone,p.email,p.role,p.created_at,p.is_approved,
    p.approved_until,p.account_suspended_until,p.account_suspension_reason
  order by p.created_at desc
$$;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_recent_cancellations(p_limit integer default 100)
returns table(
  id uuid,trip_id text,actor_id uuid,actor_name text,actor_role text,
  affected_name text,previous_status text,outcome text,reason_code text,
  reason_detail text,created_at timestamptz)
language sql stable security definer set search_path=public as $$
  select c.id,c.trip_id,c.actor_id,a.full_name,c.actor_role,b.full_name,
    c.previous_status,c.outcome,c.reason_code,c.reason_detail,c.created_at
  from public.trip_cancellation_events c
  join public.profiles a on a.id=c.actor_id
  left join public.profiles b on b.id=c.affected_user_id
  where public.is_admin()
  order by c.created_at desc limit greatest(1,least(p_limit,500))
$$;
grant execute on function public.admin_recent_cancellations(integer) to authenticated;

-- La base evita que una cuenta suspendida vuelva a aparecer online aunque use
-- una versión antigua de la APK.
create or replace function public.enforce_driver_account_enabled()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.is_online and not public.account_is_enabled(new.driver_id::text::uuid) then
    new.is_online := false;
  end if;
  return new;
end $$;
drop trigger if exists enforce_driver_account_enabled_trigger on public.driver_locations;
create trigger enforce_driver_account_enabled_trigger
before insert or update of is_online on public.driver_locations
for each row execute function public.enforce_driver_account_enabled();

commit;
