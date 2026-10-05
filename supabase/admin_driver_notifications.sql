-- QuiacaGo - notificaciones administrativas y edición segura de legajos.
-- Ejecutar una vez en el SQL Editor de Supabase después de los demás scripts.

alter table public.profiles
  add column if not exists account_suspended_until timestamptz,
  add column if not exists account_suspension_reason text,
  add column if not exists account_suspended_at timestamptz,
  add column if not exists account_suspended_by uuid;

alter table public.driver_documents
  add column if not exists review_note text;

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in (
    'new_driver','driver_suspended','driver_disabled',
    'driver_profile_updated','driver_document_updated'
  )),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  read_by uuid references public.profiles(id)
);

create index if not exists admin_notifications_unread_idx
  on public.admin_notifications(is_read,created_at desc);
create index if not exists admin_notifications_driver_idx
  on public.admin_notifications(driver_id,created_at desc);

alter table public.admin_notifications enable row level security;
drop policy if exists admin_notifications_admin_read on public.admin_notifications;
create policy admin_notifications_admin_read on public.admin_notifications
  for select to authenticated using(public.is_admin());
drop policy if exists admin_notifications_admin_update on public.admin_notifications;
create policy admin_notifications_admin_update on public.admin_notifications
  for update to authenticated using(public.is_admin()) with check(public.is_admin());

-- Permite que el municipio complete o reemplace archivos del legajo desde el panel.
drop policy if exists documents_admin_insert on public.driver_documents;
create policy documents_admin_insert on public.driver_documents
  for insert to authenticated with check(public.is_admin());

drop policy if exists driver_documents_admin_upload on storage.objects;
create policy driver_documents_admin_upload on storage.objects
  for insert to authenticated
  with check(bucket_id='driver-documents' and public.is_admin());

drop policy if exists driver_documents_admin_update on storage.objects;
create policy driver_documents_admin_update on storage.objects
  for update to authenticated
  using(bucket_id='driver-documents' and public.is_admin())
  with check(bucket_id='driver-documents' and public.is_admin());

-- Los cambios de vehículo hechos por el propio conductor requieren una nueva
-- revisión. Los cambios administrativos no interrumpen una habilitación activa.
create or replace function public.mark_driver_pending_on_vehicle_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.role='driver' and not public.is_admin() and (
    new.vehicle_info is distinct from old.vehicle_info or
    new.plate is distinct from old.plate or
    new.taxi_number is distinct from old.taxi_number
  ) then
    new.is_approved:=false;
    new.approved_until:=null;
    new.suspension_reason:='Datos del vehículo actualizados; revisión municipal pendiente';
  end if;
  return new;
end $$;

drop trigger if exists driver_vehicle_profile_changed on public.profiles;
create trigger driver_vehicle_profile_changed
before update of vehicle_info,plate,taxi_number on public.profiles
for each row execute function public.mark_driver_pending_on_vehicle_change();

create or replace function public.notify_admins_about_driver_profile()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_title text;
  v_message text;
  v_kind text;
begin
  if new.role<>'driver' then return new; end if;

  if tg_op='INSERT' then
    v_kind:='new_driver';
    v_title:='Nuevo conductor para revisar';
    v_message:=coalesce(new.full_name,'Conductor')||' creó su cuenta y su legajo está pendiente.';
  elsif new.account_suspended_until is distinct from old.account_suspended_until
    and new.account_suspended_until is not null
    and new.account_suspended_until>now() then
    v_kind:='driver_suspended';
    v_title:='Conductor suspendido';
    v_message:=coalesce(new.full_name,'Conductor')||' fue suspendido hasta '||
      to_char(new.account_suspended_until at time zone 'America/Argentina/Buenos_Aires','DD/MM/YYYY HH24:MI')||
      coalesce('. Motivo: '||nullif(new.account_suspension_reason,''),'.');
  elsif not public.is_admin() and (
    new.full_name is distinct from old.full_name or
    new.phone is distinct from old.phone or
    new.email is distinct from old.email or
    new.vehicle_info is distinct from old.vehicle_info or
    new.plate is distinct from old.plate or
    new.taxi_number is distinct from old.taxi_number or
    new.licencia_expiration is distinct from old.licencia_expiration or
    new.seguro_expiration is distinct from old.seguro_expiration or
    new.vtv_expiration is distinct from old.vtv_expiration
  ) then
    v_kind:='driver_profile_updated';
    v_title:='Datos de conductor actualizados';
    v_message:=coalesce(new.full_name,'Conductor')||' modificó datos de su legajo. Requiere revisión.';
  elsif old.is_approved=true and new.is_approved=false then
    v_kind:='driver_disabled';
    v_title:='Conductor inhabilitado';
    v_message:=coalesce(new.full_name,'Conductor')||' quedó inhabilitado. Revisá su legajo y documentación.';
  else
    return new;
  end if;

  insert into public.admin_notifications(kind,driver_id,title,message)
  values(v_kind,new.id,v_title,v_message);
  return new;
end $$;

drop trigger if exists notify_admins_driver_profile on public.profiles;
create trigger notify_admins_driver_profile
after insert or update on public.profiles
for each row execute function public.notify_admins_about_driver_profile();

create or replace function public.notify_admins_about_driver_document()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_name text;
begin
  -- Los cambios hechos desde el panel no generan un aviso para el mismo administrador.
  if public.is_admin() then return new; end if;
  select full_name into v_name from public.profiles where id=new.driver_id;
  insert into public.admin_notifications(kind,driver_id,title,message)
  values(
    'driver_document_updated',new.driver_id,'Documentación de conductor actualizada',
    coalesce(v_name,'Conductor')||' cargó o actualizó '||
      case new.document_type
        when 'dni_front' then 'el frente del DNI'
        when 'dni_back' then 'el dorso del DNI'
        when 'license' then 'la licencia'
        when 'insurance' then 'el seguro'
        when 'vtv' then 'la VTV/RTO'
        else 'un documento'
      end||'. Revisá el legajo.'
  );
  return new;
end $$;

drop trigger if exists notify_admins_driver_document on public.driver_documents;
create trigger notify_admins_driver_document
after insert or update of storage_path,expires_at on public.driver_documents
for each row execute function public.notify_admins_about_driver_document();

create or replace function public.admin_update_driver_record(
  p_driver_id uuid,
  p_full_name text,
  p_phone text,
  p_email text,
  p_vehicle_info text,
  p_plate text,
  p_taxi_number text,
  p_licencia_expiration date,
  p_seguro_expiration date,
  p_vtv_expiration date,
  p_document_updates jsonb
) returns void language plpgsql security definer set search_path=public as $$
declare item jsonb;
declare v_type text;
declare v_status text;
declare v_expires date;
declare v_review_note text;
declare v_previous_status text;
declare v_previous_note text;
begin
  if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
  if not exists(select 1 from public.profiles where id=p_driver_id and role='driver') then
    raise exception 'Conductor inexistente';
  end if;
  if nullif(trim(p_full_name),'') is null or nullif(trim(p_phone),'') is null then
    raise exception 'Nombre y teléfono son obligatorios';
  end if;

  update public.profiles set
    full_name=trim(p_full_name), phone=trim(p_phone), email=nullif(trim(p_email),''),
    vehicle_info=nullif(trim(p_vehicle_info),''), plate=nullif(upper(trim(p_plate)),''),
    taxi_number=nullif(trim(p_taxi_number),''),
    licencia_expiration=p_licencia_expiration,
    seguro_expiration=p_seguro_expiration,
    vtv_expiration=p_vtv_expiration,
    updated_at=now()
  where id=p_driver_id;

  for item in select value from jsonb_array_elements(coalesce(p_document_updates,'[]'::jsonb)) loop
    v_type:=item->>'document_type';
    v_status:=item->>'status';
    v_expires:=nullif(item->>'expires_at','')::date;
    v_review_note:=nullif(trim(item->>'review_note'),'');
    if v_type is null or v_type not in ('dni_front','dni_back','license','insurance','vtv') then
      raise exception 'Tipo de documento inválido';
    end if;
    if v_status is null or v_status not in ('pending','approved','rejected','expired') then
      raise exception 'Estado de documento inválido';
    end if;
    select status,review_note into v_previous_status,v_previous_note
      from public.driver_documents
      where driver_id=p_driver_id and document_type=v_type;
    update public.driver_documents set status=v_status,expires_at=v_expires,
      review_note=case when v_status='rejected' then v_review_note else null end
      where driver_id=p_driver_id and document_type=v_type;
    if v_status='rejected' and
      (v_previous_status is distinct from v_status or v_previous_note is distinct from v_review_note) then
      insert into public.driver_messages(driver_id,title,body,message_type,created_by)
      values(
        p_driver_id,
        'Documento observado',
        case v_type
          when 'dni_front' then 'DNI frente'
          when 'dni_back' then 'DNI dorso'
          when 'license' then 'Licencia de conducir'
          when 'insurance' then 'Seguro del taxi'
          when 'vtv' then 'VTV/RTO'
        end||' requiere una nueva carga.'||
          case when v_review_note is null then '' else ' Motivo: '||v_review_note end,
        'document',auth.uid()
      );
    end if;
  end loop;
end $$;

grant execute on function public.admin_update_driver_record(
  uuid,text,text,text,text,text,text,date,date,date,jsonb
) to authenticated;

-- Crea una bandeja inicial para conductores ya pendientes, suspendidos o inhabilitados.
insert into public.admin_notifications(kind,driver_id,title,message)
select
  case
    when p.account_suspended_until>now() then 'driver_suspended'
    when p.is_approved=false then 'driver_disabled'
    else 'driver_profile_updated'
  end,
  p.id,
  case
    when p.account_suspended_until>now() then 'Conductor suspendido para revisar'
    when p.is_approved=false then 'Conductor inhabilitado para revisar'
    else 'Legajo de conductor para revisar'
  end,
  coalesce(p.full_name,'Conductor')||' requiere revisión administrativa.'
from public.profiles p
where p.role='driver'
  and (p.is_approved=false or p.account_suspended_until>now())
  and not exists(
    select 1 from public.admin_notifications n
    where n.driver_id=p.id
      and n.kind in ('new_driver','driver_suspended','driver_disabled')
  );

