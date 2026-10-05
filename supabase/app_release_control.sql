-- QuiacaGo - control remoto de versiones beta y producción.
-- Ejecutar una vez desde Supabase SQL Editor.

begin;

create table if not exists public.app_release_controls (
  app_key text primary key check (app_key in (
    'conductor_beta','pasajero_beta',
    'conductor_production','pasajero_production'
  )),
  enabled boolean not null default true,
  minimum_build integer not null default 1 check (minimum_build > 0),
  expires_at timestamptz,
  message text not null default 'Esta versión ya no está disponible.',
  update_url text,
  notes text,
  updated_at timestamptz not null default now()
);

alter table public.app_release_controls enable row level security;

drop policy if exists app_release_controls_admin_read on public.app_release_controls;
create policy app_release_controls_admin_read on public.app_release_controls
  for select to authenticated using(public.is_admin());

drop policy if exists app_release_controls_admin_update on public.app_release_controls;
create policy app_release_controls_admin_update on public.app_release_controls
  for update to authenticated using(public.is_admin()) with check(public.is_admin());

insert into public.app_release_controls(
  app_key,enabled,minimum_build,expires_at,message,notes
) values
  ('conductor_beta',true,1,now()+interval '30 days',
   'La etapa de prueba de QuiacaGo Conductor terminó. Solicitá la versión actual.',
   'Cambiar enabled, minimum_build o expires_at desde Supabase.'),
  ('pasajero_beta',true,1,now()+interval '30 days',
   'La etapa de prueba de QuiacaGo Pasajero terminó. Solicitá la versión actual.',
   'Cambiar enabled, minimum_build o expires_at desde Supabase.'),
  ('conductor_production',true,1,null,
   'Necesitás actualizar QuiacaGo Conductor para continuar.',
   'No establecer vencimiento para producción salvo emergencia.'),
  ('pasajero_production',true,1,null,
   'Necesitás actualizar QuiacaGo Pasajero para continuar.',
   'No establecer vencimiento para producción salvo emergencia.')
on conflict(app_key) do nothing;

create or replace function public.touch_app_release_control()
returns trigger language plpgsql set search_path=public as $$
begin
  new.updated_at:=now();
  return new;
end $$;

drop trigger if exists app_release_control_updated on public.app_release_controls;
create trigger app_release_control_updated
before update on public.app_release_controls
for each row execute function public.touch_app_release_control();

create or replace function public.check_app_release(
  p_app_key text,
  p_build_number integer
) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_control public.app_release_controls%rowtype;
  v_allowed boolean;
  v_reason text;
begin
  select * into v_control
  from public.app_release_controls
  where app_key=p_app_key;

  if not found then
    v_allowed:=p_app_key in ('conductor_production','pasajero_production');
    v_reason:=case when v_allowed then 'unconfigured_production' else 'unknown_app' end;
    return jsonb_build_object(
      'allowed',v_allowed,
      'reason',v_reason,
      'message',case when v_allowed then '' else 'Esta aplicación de prueba no está autorizada.' end,
      'server_time',now()
    );
  end if;

  v_allowed:=v_control.enabled
    and p_build_number>=v_control.minimum_build
    and (v_control.expires_at is null or now()<v_control.expires_at);
  v_reason:=case
    when not v_control.enabled then 'disabled'
    when p_build_number<v_control.minimum_build then 'update_required'
    when v_control.expires_at is not null and now()>=v_control.expires_at then 'expired'
    else 'allowed'
  end;

  return jsonb_build_object(
    'allowed',v_allowed,
    'reason',v_reason,
    'message',v_control.message,
    'minimum_build',v_control.minimum_build,
    'expires_at',v_control.expires_at,
    'update_url',v_control.update_url,
    'server_time',now()
  );
end $$;

revoke all on function public.check_app_release(text,integer) from public;
grant execute on function public.check_app_release(text,integer) to anon,authenticated;

commit;
