-- QuiacaGo: migración de la base existente (no usar schema.sql sobre esta base).
-- Conserva perfiles, viajes, ubicaciones y documentos existentes.
begin;
create extension if not exists "pgcrypto";

-- Perfiles: completar contrato actual y retirar credenciales públicas inseguras.
alter table public.profiles add column if not exists suspension_reason text;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();
update public.profiles set role=lower(role) where role is not null;
update public.profiles set full_name=coalesce(nullif(full_name,''),nullif(name,''),'Usuario');
alter table public.profiles alter column full_name set not null;
alter table public.profiles drop column if exists password;

-- Viajes: se mantienen IDs text para no romper IDs históricos TRIP-*.
alter table public.trips add column if not exists passenger_id uuid references auth.users(id) on delete set null;
alter table public.trips add column if not exists payment_method text not null default 'cash';
alter table public.trips add column if not exists accepted_at timestamptz;
alter table public.trips add column if not exists started_at timestamptz;
alter table public.trips add column if not exists finished_at timestamptz;
alter table public.trips alter column id set default gen_random_uuid()::text;
create unique index if not exists driver_locations_driver_id_uidx
 on public.driver_locations(driver_id);
update public.trips set status=case upper(status)
 when 'REQUESTED' then 'requested' when 'ACCEPTED' then 'accepted'
 when 'ARRIVING' then 'accepted' when 'WAITING_PASSENGER' then 'arrived'
 when 'STARTED' then 'in_progress' when 'FINISHED' then 'completed'
 when 'CANCELLED' then 'cancelled' else lower(status) end;

-- Documentos: agregar nombres nuevos y relajar columnas heredadas para nuevos inserts.
alter table public.driver_documents add column if not exists document_type text;
alter table public.driver_documents add column if not exists storage_path text;
alter table public.driver_documents add column if not exists status text not null default 'pending';
alter table public.driver_documents add column if not exists expires_at date;
alter table public.driver_documents alter column tipo drop not null;
alter table public.driver_documents alter column titulo drop not null;
alter table public.driver_documents alter column fecha_vencimiento drop not null;
update public.driver_documents set
 document_type=coalesce(document_type,case upper(tipo)
  when 'DNI' then 'dni_front' when 'LICENSE' then 'license'
  when 'INSURANCE' then 'insurance' when 'VTV' then 'vtv' else lower(tipo) end),
 storage_path=coalesce(storage_path,documento_url),
 status=case when estado is not null then lower(estado::text) else status end;
update public.driver_documents set
 expires_at=coalesce(expires_at,fecha_vencimiento::date);

-- Vincula un perfil legado con el nuevo usuario Auth que use el mismo teléfono.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
declare legacy public.profiles%rowtype;
begin
 select * into legacy from public.profiles
 where phone=coalesce(new.raw_user_meta_data->>'phone',new.phone)
 order by created_at limit 1;
 if legacy.id is not null then
   update public.profiles set phone=phone||'.legacy.'||id::text,
     plate=null,taxi_number=null where id=legacy.id;
 end if;
 insert into public.profiles(id,full_name,name,phone,email,role,is_approved,
   vehicle_info,plate,taxi_number,approved_until,licencia_expiration,vtv_expiration,seguro_expiration)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',legacy.full_name,'Usuario'),
   coalesce(new.raw_user_meta_data->>'full_name',legacy.name,'Usuario'),
   coalesce(new.raw_user_meta_data->>'phone',new.phone,new.id::text),new.email,
   coalesce(new.raw_user_meta_data->>'role',legacy.role,'passenger'),
   coalesce(legacy.is_approved,(new.raw_user_meta_data->>'role')='passenger'),
   legacy.vehicle_info,legacy.plate,legacy.taxi_number,legacy.approved_until,
   legacy.licencia_expiration,legacy.vtv_expiration,legacy.seguro_expiration);
 if legacy.id is not null then
   update public.driver_documents set driver_id=new.id where driver_id=legacy.id;
   update public.driver_locations set driver_id=new.id::text where driver_id=legacy.id::text;
   update public.trips set driver_id=new.id::text where driver_id=legacy.id::text;
   delete from public.profiles where id=legacy.id;
 end if;
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Aceptación atómica adaptada al ID text existente.
create or replace function public.accept_trip(p_trip_id text,p_driver_name text,p_vehicle_info text)
returns public.trips language plpgsql security definer set search_path=public as $$
declare result public.trips;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='driver'
   and is_approved and (approved_until is null or approved_until>=now()))
 then raise exception 'Conductor no habilitado'; end if;
 update public.trips set driver_id=auth.uid()::text,driver_name=p_driver_name,
   vehicle_info=p_vehicle_info,status='accepted',accepted_at=now()
 where id=p_trip_id and status='requested' and driver_id is null returning * into result;
 if result.id is null then raise exception 'El viaje ya no está disponible'; end if;
 return result;
end $$;

create or replace function public.is_admin() returns boolean language sql stable
security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin')
$$;

-- Reemplazar políticas públicas anteriores.
alter table public.profiles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.trips enable row level security;
alter table public.driver_locations enable row level security;
do $$ declare p record; begin
 for p in select policyname,tablename from pg_policies where schemaname='public'
  and tablename in ('profiles','driver_documents','trips','driver_locations')
 loop execute format('drop policy if exists %I on public.%I',p.policyname,p.tablename); end loop;
end $$;
create policy profiles_read on public.profiles for select to authenticated using(true);
create policy profiles_self_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy profiles_admin_update on public.profiles for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy documents_owner on public.driver_documents for all to authenticated using(driver_id=auth.uid()) with check(driver_id=auth.uid());
create policy documents_admin_read on public.driver_documents for select to authenticated using(public.is_admin());
create policy trips_create on public.trips for insert to authenticated with check(passenger_id=auth.uid() and driver_id is null and status='requested');
create policy trips_read on public.trips for select to authenticated using(passenger_id=auth.uid() or driver_id=auth.uid()::text or
 (status='requested' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='driver' and p.is_approved)));
create policy trips_passenger_cancel on public.trips for update to authenticated using(passenger_id=auth.uid() and status='requested')
 with check(passenger_id=auth.uid() and status='cancelled');
create policy trips_driver_update on public.trips for update to authenticated using(driver_id=auth.uid()::text) with check(driver_id=auth.uid()::text);
create policy locations_read on public.driver_locations for select to authenticated using(true);
create policy locations_driver_write on public.driver_locations for all to authenticated
 using(driver_id=auth.uid()::text) with check(driver_id=auth.uid()::text);
grant execute on function public.accept_trip(text,text,text) to authenticated;

insert into storage.buckets(id,name,public) values('driver-documents','driver-documents',false)
on conflict(id) do nothing;
drop policy if exists driver_documents_upload on storage.objects;
drop policy if exists driver_documents_read_own on storage.objects;
drop policy if exists driver_documents_read_admin on storage.objects;
create policy driver_documents_upload on storage.objects for insert to authenticated
 with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy driver_documents_read_own on storage.objects for select to authenticated
 using(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy driver_documents_read_admin on storage.objects for select to authenticated
 using(bucket_id='driver-documents' and public.is_admin());
commit;
