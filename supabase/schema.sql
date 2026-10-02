-- QuiacaGo - esquema canónico seguro para Supabase.
create extension if not exists "pgcrypto";
create type public.user_role as enum ('passenger', 'driver', 'admin');
create type public.trip_status as enum ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending','completed','cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null, phone text not null unique, email text,
  role public.user_role not null default 'passenger', is_approved boolean not null default false,
  approved_until timestamptz, suspension_reason text,
  licencia_expiration date, seguro_expiration date, vtv_expiration date,
  vehicle_info text, plate text unique, taxi_number text unique,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.passenger_private_data (
  passenger_id uuid primary key references public.profiles(id) on delete cascade,
  dni text not null, birth_date date not null, created_at timestamptz not null default now()
);
create table public.driver_documents (
  id uuid primary key default gen_random_uuid(), driver_id uuid not null references public.profiles(id) on delete cascade,
  document_type text not null check (document_type in ('dni_front','dni_back','license','insurance','vtv')),
  storage_path text not null, status text not null default 'pending' check (status in ('pending','approved','rejected','expired')),
  expires_at date, created_at timestamptz not null default now(), unique(driver_id, document_type)
);
create table public.trips (
  id uuid primary key default gen_random_uuid(), passenger_id uuid not null references public.profiles(id),
  passenger_name text not null, passenger_phone text not null, driver_id uuid references public.profiles(id),
  driver_name text, vehicle_info text, pickup_address text not null, pickup_lat double precision not null,
  pickup_lng double precision not null, destination_address text not null, destination_lat double precision not null,
  destination_lng double precision not null, fare_amount numeric(10,2) not null check (fare_amount >= 0),
  pin_code text not null check (pin_code ~ '^[0-9]{4}$'),
  finish_code text not null default lpad((floor(random()*9000)+1000)::int::text,4,'0') check (finish_code ~ '^[0-9]{4}$'),
  start_code_used_at timestamptz, finish_code_used_at timestamptz,
  code_expires_at timestamptz not null default (now()+interval '4 hours'),
  status public.trip_status not null default 'requested', payment_method text not null default 'cash',
  payment_status text not null default 'pending', payment_confirmed_at timestamptz, cancellation_reason text,
  created_at timestamptz not null default now(), accepted_at timestamptz, started_at timestamptz, finished_at timestamptz
);
create table public.driver_locations (
  driver_id uuid primary key references public.profiles(id) on delete cascade, driver_name text not null,
  vehicle_info text not null, plate text not null, latitude double precision not null, longitude double precision not null,
  heading double precision not null default 0, is_online boolean not null default false, updated_at timestamptz not null default now()
);
create index trips_status_created_idx on public.trips(status, created_at desc);
create index trips_passenger_idx on public.trips(passenger_id, created_at desc);
create index trips_driver_idx on public.trips(driver_id, created_at desc);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,phone,email,role,is_approved) values(
  new.id,coalesce(new.raw_user_meta_data->>'full_name','Usuario'),
  coalesce(new.raw_user_meta_data->>'phone',new.phone,new.id::text),new.email,
  coalesce((new.raw_user_meta_data->>'role')::public.user_role,'passenger'),
  coalesce((new.raw_user_meta_data->>'role')='passenger',false));
 update public.profiles set
  vehicle_info=new.raw_user_meta_data->>'vehicle_info',
  plate=nullif(new.raw_user_meta_data->>'plate',''),
  taxi_number=nullif(new.raw_user_meta_data->>'taxi_number',''),
  licencia_expiration=nullif(new.raw_user_meta_data->>'licencia_expiration','')::date,
  seguro_expiration=nullif(new.raw_user_meta_data->>'seguro_expiration','')::date,
  vtv_expiration=nullif(new.raw_user_meta_data->>'vtv_expiration','')::date
 where id=new.id and (new.raw_user_meta_data->>'role')='driver';
 if (new.raw_user_meta_data->>'role')='passenger' then
  insert into public.passenger_private_data(passenger_id,dni,birth_date) values(
   new.id,new.raw_user_meta_data->>'dni',
   (new.raw_user_meta_data->>'birth_date')::date);
 end if;
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Compare-and-set: sólo un conductor puede aceptar cada solicitud.
create or replace function public.accept_trip(p_trip_id uuid,p_driver_name text,p_vehicle_info text)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='driver' and is_approved
   and (approved_until is null or approved_until>=now())) then raise exception 'Conductor no habilitado'; end if;
 update public.trips set driver_id=auth.uid(),driver_name=p_driver_name,vehicle_info=p_vehicle_info,
   status='accepted',accepted_at=now() where id=p_trip_id and status='requested' and driver_id is null returning * into result;
 if result.id is null then raise exception 'El viaje ya no está disponible'; end if; return result;
end $$;

alter table public.profiles enable row level security;
alter table public.passenger_private_data enable row level security;
alter table public.driver_documents enable row level security;
alter table public.trips enable row level security;
alter table public.driver_locations enable row level security;
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy passenger_private_self on public.passenger_private_data for select to authenticated
 using(passenger_id=auth.uid());
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin')
$$;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
 using(id=auth.uid() or public.is_admin());
create policy profiles_admin_update on public.profiles for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy passenger_private_admin on public.passenger_private_data for select to authenticated using(public.is_admin());
create policy documents_owner on public.driver_documents for all to authenticated using(driver_id=auth.uid()) with check(driver_id=auth.uid());
create policy documents_admin_read on public.driver_documents for select to authenticated using(public.is_admin());
create policy documents_admin_update on public.driver_documents for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy trips_create on public.trips for insert to authenticated with check(passenger_id=auth.uid() and driver_id is null and status='requested');
create policy trips_read on public.trips for select to authenticated using(passenger_id=auth.uid() or driver_id=auth.uid() or
 (status='requested' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='driver' and p.is_approved)));
create policy trips_passenger_cancel on public.trips for update to authenticated using(passenger_id=auth.uid() and status='requested')
 with check(passenger_id=auth.uid() and status='cancelled');
create policy trips_driver_update on public.trips for update to authenticated using(driver_id=auth.uid()) with check(driver_id=auth.uid());
create policy locations_read on public.driver_locations for select to authenticated using(true);
create policy locations_driver_write on public.driver_locations for all to authenticated using(driver_id=auth.uid()) with check(driver_id=auth.uid());
grant execute on function public.accept_trip(uuid,text,text) to authenticated;
insert into storage.buckets(id,name,public) values('driver-documents','driver-documents',false)
on conflict(id) do nothing;
create policy driver_documents_upload on storage.objects for insert to authenticated
 with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy driver_documents_update on storage.objects for update to authenticated
 using(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text)
 with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy driver_documents_read_own on storage.objects for select to authenticated
 using(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy driver_documents_read_admin on storage.objects for select to authenticated
 using(bucket_id='driver-documents' and public.is_admin());

create or replace function public.mark_driver_pending_on_document_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update public.profiles set is_approved=false,approved_until=null,
  suspension_reason='Documentación nueva pendiente de revisión' where id=new.driver_id;
 return new;
end $$;
create trigger driver_document_changed after insert or update of storage_path,expires_at
 on public.driver_documents for each row execute function public.mark_driver_pending_on_document_change();

create or replace function public.review_driver(
 p_driver_id uuid,p_approved boolean,p_days integer default 30)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
 if p_approved and (
  (select count(distinct document_type) from public.driver_documents where driver_id=p_driver_id
   and document_type in ('dni_front','dni_back','license','insurance','vtv'))<5
  or exists(select 1 from public.driver_documents where driver_id=p_driver_id
   and document_type in ('license','insurance','vtv')
   and (expires_at is null or expires_at<current_date))
 ) then raise exception 'El legajo está incompleto o contiene documentos vencidos'; end if;
 update public.driver_documents set status=case when p_approved then 'approved' else 'rejected' end
  where driver_id=p_driver_id;
 update public.profiles set is_approved=p_approved,
  approved_until=case when p_approved then now()+(greatest(1,least(p_days,365))||' days')::interval else null end,
  suspension_reason=case when p_approved then null else 'Documentación rechazada por la administración municipal' end
  where id=p_driver_id and role='driver';
end $$;
grant execute on function public.review_driver(uuid,boolean,integer) to authenticated;
revoke update on public.profiles from authenticated;
grant update(full_name,phone,vehicle_info,plate,taxi_number,
 licencia_expiration,seguro_expiration,vtv_expiration) on public.profiles to authenticated;
alter publication supabase_realtime add table public.trips;
alter publication supabase_realtime add table public.driver_locations;
