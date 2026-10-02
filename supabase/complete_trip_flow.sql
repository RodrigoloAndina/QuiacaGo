-- Ejecutar después de migrate_existing.sql.
-- Agrega el flujo seguro de inicio, finalización y pago en efectivo.
begin;

alter table public.trips add column if not exists finish_code text;
alter table public.trips add column if not exists start_code_used_at timestamptz;
alter table public.trips add column if not exists finish_code_used_at timestamptz;
alter table public.trips add column if not exists code_expires_at timestamptz;
alter table public.trips add column if not exists payment_status text not null default 'pending';
alter table public.trips add column if not exists payment_confirmed_at timestamptz;
alter table public.trips add column if not exists offered_driver_id text;
alter table public.trips add column if not exists offer_started_at timestamptz;
alter table public.trips add column if not exists offer_expires_at timestamptz;

-- La tabla heredada utilizaba una cadena vacía como conductor no asignado.
-- El despachador trabaja con NULL; normalizar datos y evitar nuevos defaults.
alter table public.trips alter column driver_id drop default;
update public.trips set driver_id=null
where nullif(btrim(driver_id::text),'') is null and driver_id is not null;

create table if not exists public.trip_offer_rejections (
 trip_id text not null references public.trips(id) on delete cascade,
 driver_id text not null,
 rejected_at timestamptz not null default now(),
 primary key(trip_id,driver_id)
);
create index if not exists trips_dispatch_idx
 on public.trips(status,offer_expires_at,created_at);

create or replace function public.random_trip_code() returns text
language sql volatile set search_path=public as $$
  select lpad((floor(random()*9000)+1000)::int::text,4,'0')
$$;

create or replace function public.prepare_trip_codes() returns trigger
language plpgsql set search_path=public as $$
begin
  new.pin_code := public.random_trip_code();
  new.finish_code := public.random_trip_code();
  while new.finish_code = new.pin_code loop
    new.finish_code := public.random_trip_code();
  end loop;
  new.code_expires_at := now() + interval '4 hours';
  new.payment_status := 'pending';
  return new;
end $$;

drop trigger if exists prepare_trip_codes_trigger on public.trips;
create trigger prepare_trip_codes_trigger before insert on public.trips
for each row execute function public.prepare_trip_codes();

update public.trips set
 finish_code=coalesce(finish_code,public.random_trip_code()),
 code_expires_at=coalesce(code_expires_at,created_at+interval '4 hours'),
 payment_status=coalesce(payment_status,'pending')
where status not in ('completed','cancelled');

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
 update public.trips set status='cancelled',
   cancellation_reason='Reemplazada por una nueva solicitud'
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

-- Entrega una oferta a un único conductor. El puntaje combina distancia al
-- pasajero con una bonificación de 50 metros por cada hora sin viajes
-- (hasta 24 horas), evitando que un conductor acapare las solicitudes.
create or replace function public.get_driver_trip_offer()
returns public.trips language plpgsql security definer set search_path=public as $$
declare
 v_now timestamptz := clock_timestamp();
 v_driver_id text := auth.uid()::text;
 v_trip public.trips;
 v_best_driver text;
begin
 if auth.uid() is null then return null; end if;
 if not exists(select 1 from public.profiles p where p.id=auth.uid()
   and p.role='driver' and p.is_approved
   and (p.approved_until is null or p.approved_until>=v_now)) then
   return null;
 end if;

 -- Serializa el despachador para que dos teléfonos no asignen la misma oferta.
 perform pg_advisory_xact_lock(hashtext('quiacago_trip_dispatch'));

 -- Limpiar solicitudes y ofertas abandonadas.
 update public.trips set status='cancelled',
   cancellation_reason=coalesce(cancellation_reason,'Solicitud vencida'),
   offered_driver_id=null,offer_expires_at=null
 where status in ('requested','buscando','pending')
   and nullif(btrim(driver_id::text),'') is null
   and created_at < v_now-interval '10 minutes';
 update public.trips set status='requested'
 where status in ('buscando','pending')
   and nullif(btrim(driver_id::text),'') is null;
 -- Una oferta vencida cuenta como no aceptada. Guardarla antes de liberarla
 -- evita que el conductor más cercano reciba el mismo pedido repetidamente.
 insert into public.trip_offer_rejections(trip_id,driver_id,rejected_at)
 select id,offered_driver_id,v_now from public.trips
 where status='requested' and offered_driver_id is not null
   and offer_expires_at<=v_now
 on conflict(trip_id,driver_id) do update set rejected_at=excluded.rejected_at;

 update public.trips set offered_driver_id=null,offer_started_at=null,
   offer_expires_at=null
 where status='requested' and offer_expires_at<=v_now;

 select * into v_trip from public.trips
 where status='requested' and offered_driver_id=v_driver_id
   and offer_expires_at>v_now
 order by offer_started_at limit 1;
 if v_trip.id is not null then return v_trip; end if;

 -- Un conductor con un servicio vigente no puede recibir otra oferta.
 if exists(select 1 from public.trips where driver_id=v_driver_id
   and status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending')) then
   return null;
 end if;

 select * into v_trip from public.trips
 where status='requested' and nullif(btrim(driver_id::text),'') is null
   and offered_driver_id is null
 order by created_at limit 1 for update skip locked;
 if v_trip.id is null then return null; end if;

 select dl.driver_id into v_best_driver
 from public.driver_locations dl
 join public.profiles p on p.id::text=dl.driver_id
 left join lateral (
   select max(t.finished_at) as last_trip_at from public.trips t
   where t.driver_id=dl.driver_id and t.status='completed'
 ) history on true
 where dl.is_online=true and dl.updated_at>=v_now-interval '20 seconds'
   and p.role='driver' and p.is_approved
   and (p.approved_until is null or p.approved_until>=v_now)
   and not exists(select 1 from public.trips active_trip
     where active_trip.driver_id=dl.driver_id
       and active_trip.status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending'))
   and not exists(select 1 from public.trips active_offer
     where active_offer.offered_driver_id=dl.driver_id
       and active_offer.status='requested' and active_offer.offer_expires_at>v_now)
   and not exists(select 1 from public.trip_offer_rejections rejected
     where rejected.trip_id=v_trip.id and rejected.driver_id=dl.driver_id)
 order by
   (6371.0*2.0*asin(sqrt(least(1.0,
     power(sin(radians((dl.latitude-v_trip.pickup_lat)/2.0)),2)+
     cos(radians(v_trip.pickup_lat))*cos(radians(dl.latitude))*
     power(sin(radians((dl.longitude-v_trip.pickup_lng)/2.0)),2)
   ))) - least(coalesce(extract(epoch from (v_now-history.last_trip_at))/3600.0,24.0),24.0)*0.05),
   history.last_trip_at asc nulls first,dl.updated_at desc
 limit 1;

 if v_best_driver is null then return null; end if;
 update public.trips set offered_driver_id=v_best_driver,
   offer_started_at=v_now,offer_expires_at=v_now+interval '20 seconds'
 where id=v_trip.id returning * into v_trip;
 if v_best_driver=v_driver_id then return v_trip; end if;
 return null;
end $$;

create or replace function public.decline_trip_offer(p_trip_id text)
returns boolean language plpgsql security definer set search_path=public as $$
declare declined boolean;
begin
 insert into public.trip_offer_rejections(trip_id,driver_id)
 select id,auth.uid()::text from public.trips
 where id=p_trip_id and status='requested' and offered_driver_id=auth.uid()::text
 on conflict(trip_id,driver_id) do update set rejected_at=now();
 update public.trips set offered_driver_id=null,offer_started_at=null,
   offer_expires_at=null
 where id=p_trip_id and status='requested' and offered_driver_id=auth.uid()::text;
 declined := found;
 return declined;
end $$;

-- El proyecto heredado usa trips.id y trips.driver_id como text. Elimina la
-- sobrecarga UUID de instalaciones anteriores para que PostgREST no encuentre
-- dos funciones accept_trip con los mismos nombres de parámetros.
drop function if exists public.accept_trip(uuid,text,text);

create or replace function public.accept_trip(
 p_trip_id text,p_driver_name text,p_vehicle_info text)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips;
begin
 if auth.uid() is null then
   raise exception 'Sesión de conductor vencida';
 end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and role='driver') then
   raise exception 'La cuenta no tiene rol driver';
 end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and is_approved) then
   raise exception 'Conductor no aprobado';
 end if;
 if exists(select 1 from public.profiles where id=auth.uid()
   and approved_until is not null and approved_until<now()) then
   raise exception 'Habilitación vencida';
 end if;
 update public.trips set driver_id=auth.uid()::text,driver_name=p_driver_name,
   vehicle_info=p_vehicle_info,status='accepted',accepted_at=now(),
   offered_driver_id=null,offer_expires_at=null
 where id=p_trip_id and status='requested'
   and nullif(btrim(driver_id::text),'') is null
   and offered_driver_id=auth.uid()::text and offer_expires_at>clock_timestamp()
 returning * into result;
 if result.id is null then
   if exists(select 1 from public.trips where id=p_trip_id and status='requested'
     and offered_driver_id=auth.uid()::text and offer_expires_at<=clock_timestamp()) then
     raise exception 'La oferta venció';
   elsif exists(select 1 from public.trips where id=p_trip_id and status='requested') then
     raise exception 'La oferta ya no está asignada a este conductor';
   else
     raise exception 'El viaje ya no está disponible';
   end if;
 end if;
 return result;
end $$;

create or replace function public.mark_arrived(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='arrived',code_expires_at=now()+interval '30 minutes'
 where id=p_trip_id and driver_id=auth.uid()::text and status='accepted';
 return found;
end $$;

create or replace function public.verify_start_code(p_trip_id text,p_code text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='in_progress',started_at=now(),start_code_used_at=now(),
   code_expires_at=now()+interval '4 hours'
 where id=p_trip_id and driver_id=auth.uid()::text and status='arrived'
   and start_code_used_at is null and code_expires_at>now() and pin_code=p_code;
 return found;
end $$;

create or replace function public.request_finish_code(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='awaiting_finish_code',code_expires_at=now()+interval '30 minutes'
 where id=p_trip_id and driver_id=auth.uid()::text and status='in_progress';
 return found;
end $$;

create or replace function public.verify_finish_code(p_trip_id text,p_code text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='payment_pending',finish_code_used_at=now()
 where id=p_trip_id and driver_id=auth.uid()::text and status='awaiting_finish_code'
   and finish_code_used_at is null and code_expires_at>now() and finish_code=p_code;
 return found;
end $$;

create or replace function public.confirm_cash_payment(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set status='completed',payment_status='paid',
   payment_confirmed_at=now(),finished_at=now()
 where id=p_trip_id and passenger_id=auth.uid() and status='payment_pending'
   and finish_code_used_at is not null;
 return found;
end $$;

grant execute on function public.mark_arrived(text) to authenticated;
grant execute on function public.accept_trip(text,text,text) to authenticated;
grant execute on function public.get_driver_trip_offer() to authenticated;
grant execute on function public.decline_trip_offer(text) to authenticated;
grant execute on function public.create_trip(text,text,text,double precision,double precision,text,double precision,double precision,double precision) to authenticated;
grant execute on function public.verify_start_code(text,text) to authenticated;
grant execute on function public.request_finish_code(text) to authenticated;
grant execute on function public.verify_finish_code(text,text) to authenticated;
grant execute on function public.confirm_cash_payment(text) to authenticated;

-- Las transiciones del conductor sólo pueden realizarse mediante las RPC anteriores.
drop policy if exists trips_driver_update on public.trips;

-- Las solicitudes pendientes sólo son visibles para el pasajero y el único
-- conductor que tiene la oferta vigente. La función SECURITY DEFINER realiza
-- la selección sin exponer el resto de la cola.
drop policy if exists trips_read on public.trips;
create policy trips_read on public.trips for select to authenticated using(
 passenger_id=auth.uid() or driver_id=auth.uid()::text or public.is_admin() or
 (status='requested' and offered_driver_id=auth.uid()::text
   and offer_expires_at>clock_timestamp())
);

drop policy if exists trips_admin_read on public.trips;
create policy trips_admin_read on public.trips for select to authenticated using(public.is_admin());
alter table public.trip_offer_rejections enable row level security;
commit;
