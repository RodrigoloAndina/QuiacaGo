-- Ejecutar una vez en Supabase SQL Editor sobre la base existente.
begin;

-- Completa instalaciones existentes sin borrar documentos ya cargados.
alter table public.driver_documents
 add column if not exists expires_at date;
do $$
begin
 if exists(
   select 1 from information_schema.columns
   where table_schema='public' and table_name='driver_documents'
     and column_name='fecha_vencimiento'
 ) then
   execute 'update public.driver_documents
            set expires_at=coalesce(expires_at,fecha_vencimiento::date)';
 end if;
end $$;

create table if not exists public.passenger_private_data (
  passenger_id uuid primary key references public.profiles(id) on delete cascade,
  dni text not null,
  birth_date date not null,
  created_at timestamptz not null default now()
);
alter table public.passenger_private_data enable row level security;

drop policy if exists passenger_private_self on public.passenger_private_data;
drop policy if exists passenger_private_admin on public.passenger_private_data;
create policy passenger_private_self on public.passenger_private_data
 for select to authenticated using(passenger_id=auth.uid());
create policy passenger_private_admin on public.passenger_private_data
 for select to authenticated using(public.is_admin());

-- Los datos de contacto de perfiles no deben ser visibles para todos los usuarios.
drop policy if exists profiles_read on public.profiles;
drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
 using(id=auth.uid() or public.is_admin());

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
   vehicle_info,plate,taxi_number,approved_until,licencia_expiration,
   vtv_expiration,seguro_expiration)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',legacy.full_name,'Usuario'),
   coalesce(new.raw_user_meta_data->>'full_name',legacy.name,'Usuario'),
   coalesce(new.raw_user_meta_data->>'phone',new.phone,new.id::text),new.email,
   coalesce(new.raw_user_meta_data->>'role',legacy.role,'passenger'),
   coalesce(legacy.is_approved,(new.raw_user_meta_data->>'role')='passenger'),
   coalesce(new.raw_user_meta_data->>'vehicle_info',legacy.vehicle_info),
   coalesce(nullif(new.raw_user_meta_data->>'plate',''),legacy.plate),
   coalesce(nullif(new.raw_user_meta_data->>'taxi_number',''),legacy.taxi_number),
   legacy.approved_until,
   coalesce(nullif(new.raw_user_meta_data->>'licencia_expiration','')::date,legacy.licencia_expiration),
   coalesce(nullif(new.raw_user_meta_data->>'vtv_expiration','')::date,legacy.vtv_expiration),
   coalesce(nullif(new.raw_user_meta_data->>'seguro_expiration','')::date,legacy.seguro_expiration));
 if (new.raw_user_meta_data->>'role')='passenger' then
   insert into public.passenger_private_data(passenger_id,dni,birth_date)
   values(new.id,new.raw_user_meta_data->>'dni',
     (new.raw_user_meta_data->>'birth_date')::date);
 end if;
 if legacy.id is not null then
   update public.driver_documents set driver_id=new.id where driver_id=legacy.id;
   update public.driver_locations set driver_id=new.id::text where driver_id=legacy.id::text;
   update public.trips set driver_id=new.id::text where driver_id=legacy.id::text;
   delete from public.profiles where id=legacy.id;
 end if;
 return new;
end $$;

drop policy if exists documents_admin_update on public.driver_documents;
create policy documents_admin_update on public.driver_documents for update to authenticated
 using(public.is_admin()) with check(public.is_admin());

drop policy if exists driver_documents_update on storage.objects;
create policy driver_documents_update on storage.objects for update to authenticated
 using(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text)
 with check(bucket_id='driver-documents' and (storage.foldername(name))[1]=auth.uid()::text);

create or replace function public.mark_driver_pending_on_document_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update public.profiles set is_approved=false, approved_until=null,
  suspension_reason='Documentación nueva pendiente de revisión'
 where id=new.driver_id;
 return new;
end $$;
drop trigger if exists driver_document_changed on public.driver_documents;
create trigger driver_document_changed after insert or update of storage_path,expires_at
 on public.driver_documents for each row
 execute function public.mark_driver_pending_on_document_change();

drop function if exists public.review_driver(uuid,boolean);
create or replace function public.review_driver(
 p_driver_id uuid,p_approved boolean,p_days integer default 30)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
 if not exists(select 1 from public.profiles where id=p_driver_id and role='driver') then
  raise exception 'El perfil no pertenece a un conductor';
 end if;
 if p_approved and (
   (select count(distinct document_type) from public.driver_documents
    where driver_id=p_driver_id and document_type in
      ('dni_front','dni_back','license','insurance','vtv')) < 5
   or exists(select 1 from public.driver_documents where driver_id=p_driver_id
     and document_type in ('license','insurance','vtv')
     and (expires_at is null or expires_at<current_date))
 ) then raise exception 'El legajo está incompleto o contiene documentos vencidos'; end if;

 update public.driver_documents set status=case when p_approved then 'approved' else 'rejected' end
 where driver_id=p_driver_id;
 update public.profiles set is_approved=p_approved,
  approved_until=case when p_approved then now()+(greatest(1,least(p_days,365))||' days')::interval else null end,
  suspension_reason=case when p_approved then null
   else 'Documentación rechazada por la administración municipal' end
 where id=p_driver_id;
end $$;
grant execute on function public.review_driver(uuid,boolean,integer) to authenticated;

-- Evita que un conductor pueda aprobarse modificando directamente su perfil.
revoke update on public.profiles from authenticated;
grant update(full_name,phone,vehicle_info,plate,taxi_number,
 licencia_expiration,seguro_expiration,vtv_expiration) on public.profiles to authenticated;

commit;
