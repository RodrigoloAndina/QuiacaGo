-- Aplicar AL FINAL de las migraciones. Idempotente. No aplica cambios remotos.
begin;

alter table public.profiles add column if not exists deletion_requested_at timestamptz;
alter table public.trips add column if not exists passenger_paid_at timestamptz;
alter table public.system_settings add column if not exists text_value text;
alter table public.system_settings add column if not exists description text;

-- El rol y la aprobación nunca provienen de metadata controlable por el usuario.
-- La coincidencia de teléfono NO acredita la propiedad de un legajo anterior.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_role text:=case when new.raw_user_meta_data->>'role'='driver' then 'driver' else 'passenger' end;
begin
 insert into public.profiles(id,full_name,name,phone,email,role,is_approved,
   vehicle_info,plate,taxi_number,licencia_expiration,seguro_expiration,vtv_expiration)
 values(new.id,left(coalesce(nullif(btrim(new.raw_user_meta_data->>'full_name'),''),'Usuario'),120),
   left(coalesce(nullif(btrim(new.raw_user_meta_data->>'full_name'),''),'Usuario'),120),
   coalesce(nullif(new.raw_user_meta_data->>'phone',''),new.phone,new.id::text),new.email,v_role,v_role='passenger',
   case when v_role='driver' then left(new.raw_user_meta_data->>'vehicle_info',160) end,
   case when v_role='driver' then nullif(upper(btrim(new.raw_user_meta_data->>'plate')),'') end,
   case when v_role='driver' then nullif(btrim(new.raw_user_meta_data->>'taxi_number'),'') end,
   case when v_role='driver' then nullif(new.raw_user_meta_data->>'licencia_expiration','')::date end,
   case when v_role='driver' then nullif(new.raw_user_meta_data->>'seguro_expiration','')::date end,
   case when v_role='driver' then nullif(new.raw_user_meta_data->>'vtv_expiration','')::date end);
 if v_role='passenger' and nullif(new.raw_user_meta_data->>'dni','') is not null
   and nullif(new.raw_user_meta_data->>'birth_date','') is not null then
   insert into public.passenger_private_data(passenger_id,dni,birth_date)
   values(new.id,left(new.raw_user_meta_data->>'dni',20),(new.raw_user_meta_data->>'birth_date')::date);
 end if;
 return new;
end $$;

create table if not exists public.legal_consents (
 user_id uuid not null references public.profiles(id) on delete cascade,
 version text not null, accepted_at timestamptz not null default now(),
 primary key(user_id,version)
);
alter table public.legal_consents enable row level security;
drop policy if exists legal_consents_read on public.legal_consents;
create policy legal_consents_read on public.legal_consents for select to authenticated
 using(user_id=auth.uid() or public.is_admin());
insert into public.system_settings(key,text_value,description)
 values('legal_version','2026-10-04','Versión vigente de términos, privacidad y reglas de operación')
 on conflict(key) do nothing;

create or replace function public.get_my_legal_acceptance() returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object('version',s.text_value,'accepted',exists(
   select 1 from public.legal_consents c where c.user_id=auth.uid() and c.version=s.text_value),
   'accepted_at',(select c.accepted_at from public.legal_consents c where c.user_id=auth.uid() and c.version=s.text_value))
 from public.system_settings s where s.key='legal_version'
$$;
create or replace function public.accept_legal_documents(p_version text) returns void
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Sesión vencida'; end if;
 if p_version is distinct from (select text_value from public.system_settings where key='legal_version') then
   raise exception 'Los documentos cambiaron. Volvé a abrirlos antes de aceptar'; end if;
 insert into public.legal_consents(user_id,version) values(auth.uid(),p_version) on conflict do nothing;
end $$;
create or replace function public.has_current_legal_consent(p_user_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.legal_consents c join public.system_settings s
   on s.key='legal_version' and s.text_value=c.version where c.user_id=p_user_id)
$$;

create or replace function public.account_is_enabled(p_user_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=p_user_id and deletion_requested_at is null
   and (account_suspended_until is null or account_suspended_until<=now()))
$$;

-- Una solicitud por pasajero y un servicio aceptado por conductor. El bloqueo
-- por perfil cubre también reintentos simultáneos desde dos dispositivos.
create or replace function public.create_trip(
 p_passenger_name text,p_passenger_phone text,p_pickup_address text,
 p_pickup_lat double precision,p_pickup_lng double precision,
 p_destination_address text,p_destination_lat double precision,
 p_destination_lng double precision,p_fare_amount double precision)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips; v_profile public.profiles;
begin
 select * into v_profile from public.profiles where id=auth.uid() for update;
 if v_profile.id is null or v_profile.role<>'passenger' then raise exception 'La sesión no pertenece a un pasajero'; end if;
 if not public.account_is_enabled(auth.uid()) then raise exception 'La cuenta no está habilitada'; end if;
 if not public.has_current_legal_consent(auth.uid()) then raise exception 'Aceptá los términos y la política de privacidad'; end if;
 if public.passenger_has_open_payment_dispute(auth.uid()) then raise exception 'Soporte debe resolver el pago pendiente'; end if;
 if p_pickup_lat is null or p_pickup_lng is null or p_destination_lat is null or p_destination_lng is null
   or not(p_pickup_lat between -90 and 90) or not(p_destination_lat between -90 and 90)
   or not(p_pickup_lng between -180 and 180) or not(p_destination_lng between -180 and 180)
   or nullif(btrim(p_pickup_address),'') is null or nullif(btrim(p_destination_address),'') is null then
   raise exception 'Seleccioná un origen y destino válidos'; end if;
 select * into result from public.trips where passenger_id=auth.uid()
   and status in ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending')
   order by created_at desc limit 1;
 if result.id is not null then return result; end if;
 if (select count(*) from public.trips where passenger_id=auth.uid() and created_at>now()-interval '10 minutes')>=10 then
   raise exception 'Demasiadas solicitudes. Esperá unos minutos'; end if;
 insert into public.trips(passenger_id,passenger_name,passenger_phone,pickup_address,pickup_lat,pickup_lng,
   destination_address,destination_lat,destination_lng,fare_amount,pin_code,status)
 values(auth.uid(),v_profile.full_name,v_profile.phone,left(btrim(p_pickup_address),300),p_pickup_lat,p_pickup_lng,
   left(btrim(p_destination_address),300),p_destination_lat,p_destination_lng,0,'0000','requested') returning * into result;
 return result;
end $$;

create or replace function public.accept_trip(p_trip_id text,p_driver_name text,p_vehicle_info text)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips; v_profile public.profiles;
begin
 select * into v_profile from public.profiles where id=auth.uid() for update;
 if v_profile.id is null or v_profile.role<>'driver' or not public.account_is_enabled(auth.uid()) then
   raise exception 'Conductor no habilitado'; end if;
 if not public.has_current_legal_consent(auth.uid()) then raise exception 'Aceptá los términos y la política de privacidad'; end if;
 if not public.driver_is_operational(auth.uid()) then raise exception 'Documentación pendiente o vencida'; end if;
 select * into result from public.trips where driver_id=auth.uid()::text
   and status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending')
   order by created_at desc limit 1;
 if result.id=p_trip_id then return result; end if;
 if result.id is not null then raise exception 'Ya tenés un viaje activo'; end if;
 update public.trips set driver_id=auth.uid()::text,driver_name=v_profile.full_name,
   vehicle_info=v_profile.vehicle_info,status='accepted',accepted_at=now(),
   offered_driver_id=null,offer_started_at=null,offer_expires_at=null
 where id=p_trip_id and status='requested' and driver_id is null
   and offered_driver_id=auth.uid()::text and offer_expires_at>clock_timestamp()
 returning * into result;
 if result.id is null then raise exception 'La oferta venció o ya no está disponible'; end if;
 return result;
end $$;

-- Efectivo: la declaración del pasajero no equivale a comprobación del cobro.
create or replace function public.acknowledge_cash_payment(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 update public.trips set passenger_paid_at=coalesce(passenger_paid_at,now())
 where id=p_trip_id and passenger_id=auth.uid() and status='payment_pending'
   and finish_code_used_at is not null;
 return found;
end $$;
create or replace function public.confirm_cash_payment(p_trip_id text) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_trip public.trips;
begin
 select * into v_trip from public.trips where id=p_trip_id and driver_id=auth.uid()::text for update;
 if v_trip.id is null then return false; end if;
 if v_trip.status='completed' and v_trip.payment_status='paid' then return true; end if;
 if v_trip.status<>'payment_pending' or v_trip.finish_code_used_at is null then return false; end if;
 update public.trips set status='completed',payment_status='paid',payment_confirmed_at=now(),finished_at=now()
 where id=p_trip_id;
 return true;
end $$;

-- Los PIN no se publican en trips/Realtime: sólo el pasajero puede recuperarlos.
create table if not exists public.trip_codes (
 trip_id text primary key references public.trips(id) on delete cascade,
 pin_code text not null, finish_code text not null,
 start_attempts integer not null default 0, finish_attempts integer not null default 0,
 locked_until timestamptz
);
alter table public.trip_codes enable row level security;
revoke all on public.trip_codes from anon,authenticated;
insert into public.trip_codes(trip_id,pin_code,finish_code)
 select id,pin_code,coalesce(finish_code,public.random_trip_code()) from public.trips
 where status not in ('completed','cancelled') on conflict do nothing;
update public.trips set pin_code='0000',finish_code='0000'
 where pin_code<>'0000' or finish_code is distinct from '0000';
create or replace function public.prepare_trip_codes() returns trigger
language plpgsql set search_path=public as $$
begin
 new.pin_code:='0000'; new.finish_code:='0000';
 new.code_expires_at:=now()+interval '4 hours'; new.payment_status:='pending';
 return new;
end $$;
create or replace function public.store_trip_codes() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_start text:=public.random_trip_code(); v_finish text:=public.random_trip_code();
begin
 while v_start=v_finish loop v_finish:=public.random_trip_code(); end loop;
 insert into public.trip_codes(trip_id,pin_code,finish_code) values(new.id,v_start,v_finish);
 return new;
end $$;
drop trigger if exists store_trip_codes on public.trips;
create trigger store_trip_codes after insert on public.trips for each row execute function public.store_trip_codes();
create or replace function public.get_my_trip_codes(p_trip_id text) returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object('pin_code',c.pin_code,'finish_code',c.finish_code,'code_expires_at',t.code_expires_at)
 from public.trip_codes c join public.trips t on t.id=c.trip_id
 where t.id=p_trip_id and t.passenger_id=auth.uid() and t.status not in ('completed','cancelled')
$$;
create or replace function public.verify_start_code(p_trip_id text,p_code text) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_trip public.trips; v_codes public.trip_codes;
begin
 select * into v_trip from public.trips where id=p_trip_id and driver_id=auth.uid()::text for update;
 if v_trip.id is null then return false; end if;
 if v_trip.status='in_progress' and v_trip.start_code_used_at is not null then return true; end if;
 if v_trip.status<>'arrived' or v_trip.code_expires_at<=now() then return false; end if;
 select * into v_codes from public.trip_codes where trip_id=p_trip_id for update;
 if v_codes.trip_id is null or v_codes.locked_until>now() then return false; end if;
 if p_code is distinct from v_codes.pin_code then
   update public.trip_codes set start_attempts=start_attempts+1,
     locked_until=case when (start_attempts+1)%5=0 then now()+interval '5 minutes' else null end where trip_id=p_trip_id;
   return false;
 end if;
 update public.trip_codes set locked_until=null where trip_id=p_trip_id;
 update public.trips set status='in_progress',started_at=now(),start_code_used_at=now(),code_expires_at=now()+interval '4 hours'
 where id=p_trip_id; return true;
end $$;
create or replace function public.verify_finish_code(p_trip_id text,p_code text) returns boolean
language plpgsql security definer set search_path=public as $$
declare v_trip public.trips; v_codes public.trip_codes;
begin
 select * into v_trip from public.trips where id=p_trip_id and driver_id=auth.uid()::text for update;
 if v_trip.id is null then return false; end if;
 if v_trip.status='payment_pending' and v_trip.finish_code_used_at is not null then return true; end if;
 if v_trip.status<>'awaiting_finish_code' or v_trip.code_expires_at<=now() then return false; end if;
 select * into v_codes from public.trip_codes where trip_id=p_trip_id for update;
 if v_codes.trip_id is null or v_codes.locked_until>now() then return false; end if;
 if p_code is distinct from v_codes.finish_code then
   update public.trip_codes set finish_attempts=finish_attempts+1,
     locked_until=case when (finish_attempts+1)%5=0 then now()+interval '5 minutes' else null end where trip_id=p_trip_id;
   return false;
 end if;
 update public.trips set status='payment_pending',finish_code_used_at=now() where id=p_trip_id;
 return true;
end $$;

-- Nadie se autoaprueba documentos ni cambia controles internos por REST.
revoke all on public.trips from anon,authenticated;
grant select on public.trips to authenticated;
revoke all on public.profiles from anon,authenticated;
grant select on public.profiles to authenticated;
grant update(full_name,phone,vehicle_info,plate,taxi_number,licencia_expiration,seguro_expiration,vtv_expiration)
 on public.profiles to authenticated;
revoke all on public.driver_documents from anon,authenticated;
grant select on public.driver_documents to authenticated;
grant insert(driver_id,document_type,storage_path,expires_at) on public.driver_documents to authenticated;
grant update(driver_id,document_type,storage_path,expires_at) on public.driver_documents to authenticated;
create or replace function public.protect_document_review() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and not public.is_admin() then
   if new.driver_id<>auth.uid() or not exists(select 1 from public.profiles where id=auth.uid() and role='driver' and deletion_requested_at is null) then
     raise exception 'Legajo no autorizado'; end if;
   if split_part(new.storage_path,'/',1)<>auth.uid()::text or new.storage_path like '%..%' then
     raise exception 'Archivo fuera del legajo'; end if;
   if tg_op='INSERT' or new.storage_path is distinct from old.storage_path
     or new.expires_at is distinct from old.expires_at then
     new.status:='pending'; new.review_note:=null;
   end if;
 end if;
 return new;
end $$;
drop trigger if exists protect_document_review on public.driver_documents;
create trigger protect_document_review before insert or update on public.driver_documents
 for each row execute function public.protect_document_review();

drop policy if exists locations_read on public.driver_locations;
drop policy if exists locations_driver_write on public.driver_locations;
drop policy if exists locations_read_scoped on public.driver_locations;
create policy locations_read_scoped on public.driver_locations for select to authenticated using(
 driver_id=auth.uid()::text or public.is_admin() or exists(select 1 from public.trips t
 where t.passenger_id=auth.uid() and t.driver_id=driver_locations.driver_id
 and t.status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending')));
create policy locations_driver_write on public.driver_locations for all to authenticated
 using(driver_id=auth.uid()::text and exists(select 1 from public.profiles where id=auth.uid() and role='driver' and deletion_requested_at is null))
 with check(driver_id=auth.uid()::text and exists(select 1 from public.profiles where id=auth.uid() and role='driver' and deletion_requested_at is null));
create or replace function public.enforce_driver_account_enabled() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if not(new.latitude between -90 and 90) or not(new.longitude between -180 and 180) then raise exception 'Ubicación inválida'; end if;
 new.updated_at:=now();
 if new.is_online and (not public.account_is_enabled(new.driver_id::uuid)
   or not public.driver_is_operational(new.driver_id::uuid)
   or not public.has_current_legal_consent(new.driver_id::uuid)) then new.is_online:=false; end if;
 return new;
end $$;
drop trigger if exists enforce_driver_account_enabled_trigger on public.driver_locations;
create trigger enforce_driver_account_enabled_trigger before insert or update on public.driver_locations
 for each row execute function public.enforce_driver_account_enabled();
create or replace function public.available_driver_count() returns integer
language sql stable security definer set search_path=public as $$
 select count(*)::integer from public.driver_locations dl where auth.uid() is not null and dl.is_online
 and dl.updated_at>now()-interval '90 seconds'
 and not exists(select 1 from public.trips t where t.driver_id=dl.driver_id
   and t.status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending'))
$$;

-- Límite del bucket: sólo legajos privados, 5 MiB por archivo, sin ejecutables.
update storage.buckets set public=false,file_size_limit=5242880,
 allowed_mime_types=array['image/jpeg','image/png','application/pdf'] where id='driver-documents';
drop policy if exists driver_documents_delete_own on storage.objects;
create policy driver_documents_delete_own on storage.objects for delete to authenticated
 using(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);

-- Privilegios explícitos: ninguna RPC pública se ejecuta como visitante por defecto.
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prosecdef loop
   execute format('revoke execute on function %s from public,anon',f.signature);
 end loop;
end $$;
grant execute on function public.get_my_legal_acceptance(),public.accept_legal_documents(text),
 public.acknowledge_cash_payment(text),public.get_my_trip_codes(text),public.available_driver_count() to authenticated;
grant select on public.legal_consents to authenticated;

-- Los scripts anteriores conceden estas RPC a las aplicaciones. El bloque de
-- revocación general de arriba requiere restaurarlas explícitamente al final.
grant execute on function public.check_app_release(text,integer) to anon,authenticated;
commit;
