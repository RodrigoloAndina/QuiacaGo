-- QuiacaGo - mensajes administrativos y verificación de teléfono del conductor.
-- Requiere configurar un proveedor SMS/WhatsApp en Authentication > Providers > Phone.

alter table public.profiles
  add column if not exists phone_verified_at timestamptz,
  add column if not exists phone_verified_number text;

create table if not exists public.system_settings (
  key text primary key,
  boolean_value boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.system_settings enable row level security;
insert into public.system_settings(key,boolean_value)
values('require_driver_phone_verification',false)
on conflict(key) do nothing;

create table if not exists public.driver_messages (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  message_type text not null default 'general'
    check(message_type in ('approval','rejection','suspension','reactivation','document','general')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists driver_messages_driver_created_idx
  on public.driver_messages(driver_id,created_at desc);

alter table public.driver_messages enable row level security;
drop policy if exists driver_messages_driver_read on public.driver_messages;
create policy driver_messages_driver_read on public.driver_messages
  for select to authenticated using(driver_id=auth.uid() or public.is_admin());

create or replace function public.send_driver_message(
  p_driver_id uuid,p_title text,p_body text,p_message_type text default 'general'
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
  if not exists(select 1 from public.profiles where id=p_driver_id and role='driver') then
    raise exception 'El destinatario no es un conductor';
  end if;
  if nullif(trim(p_title),'') is null or nullif(trim(p_body),'') is null then
    raise exception 'El título y el mensaje son obligatorios';
  end if;
  if p_message_type not in ('approval','rejection','suspension','reactivation','document','general') then
    raise exception 'Tipo de mensaje inválido';
  end if;
  insert into public.driver_messages(driver_id,title,body,message_type,created_by)
  values(p_driver_id,trim(p_title),trim(p_body),p_message_type,auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.mark_driver_message_read(p_message_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.driver_messages set read_at=coalesce(read_at,now())
  where id=p_message_id and driver_id=auth.uid();
end $$;

create or replace function public.confirm_my_phone_verification(p_phone text)
returns void language plpgsql security definer set search_path=public,auth as $$
declare v_auth_phone text;
declare v_confirmed timestamptz;
declare v_normalized text;
begin
  v_normalized:='+'||regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
  select '+'||regexp_replace(coalesce(phone,''),'[^0-9]','','g'),phone_confirmed_at
    into v_auth_phone,v_confirmed from auth.users where id=auth.uid();
  if v_confirmed is null or v_auth_phone is distinct from v_normalized then
    raise exception 'El teléfono todavía no fue confirmado mediante OTP';
  end if;
  update public.profiles set phone=v_normalized,phone_verified_number=v_normalized,
    phone_verified_at=now(),updated_at=now() where id=auth.uid() and role='driver';
end $$;

grant execute on function public.send_driver_message(uuid,text,text,text) to authenticated;
grant execute on function public.mark_driver_message_read(uuid) to authenticated;
grant execute on function public.confirm_my_phone_verification(text) to authenticated;

create or replace function public.clear_phone_verification_on_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.phone is distinct from old.phone
    and regexp_replace(coalesce(new.phone,''),'[^0-9]','','g') is distinct from
        regexp_replace(coalesce(old.phone_verified_number,''),'[^0-9]','','g') then
    new.phone_verified_at:=null;
    new.phone_verified_number:=null;
  end if;
  return new;
end $$;

drop trigger if exists clear_driver_phone_verification on public.profiles;
create trigger clear_driver_phone_verification
before update of phone on public.profiles
for each row when (new.role='driver')
execute function public.clear_phone_verification_on_change();

create or replace function public.review_driver_and_notify(
  p_driver_id uuid,p_approved boolean,p_days integer,
  p_title text,p_message text
) returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
  if p_approved and coalesce((select boolean_value from public.system_settings
    where key='require_driver_phone_verification'),false) and not exists(
    select 1 from public.profiles where id=p_driver_id and phone_verified_at is not null
  ) then raise exception 'El conductor todavía no verificó su número de teléfono'; end if;
  perform public.review_driver(p_driver_id,p_approved,p_days);
  if nullif(trim(p_message),'') is not null then
    perform public.send_driver_message(
      p_driver_id,
      coalesce(nullif(trim(p_title),''),case when p_approved then 'Solicitud aprobada' else 'Revisión de legajo' end),
      p_message,
      case when p_approved then 'approval' else 'rejection' end
    );
  end if;
end $$;

grant execute on function public.review_driver_and_notify(uuid,boolean,integer,text,text)
to authenticated;

