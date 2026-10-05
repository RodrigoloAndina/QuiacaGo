-- QuiacaGo - funciones obligatorias para operación en producción.
-- Consultá PRODUCTION_SETUP.md para respetar el orden de ejecución.

-- Determina la habilitación exclusivamente en el servidor. Además de la
-- aprobación municipal exige cuenta activa y los cinco documentos aprobados.
alter table public.driver_documents
  add column if not exists review_note text;

create or replace function public.driver_is_operational(p_driver_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.profiles p
    where p.id=p_driver_id and p.role='driver' and p.is_approved
      and (p.approved_until is null or p.approved_until>=now())
      and (p.account_suspended_until is null or p.account_suspended_until<=now())
      and (p.licencia_expiration is null or p.licencia_expiration>=current_date)
      and (p.seguro_expiration is null or p.seguro_expiration>=current_date)
      and (p.vtv_expiration is null or p.vtv_expiration>=current_date)
      and not exists(
        select required.document_type
        from (values ('dni_front'),('dni_back'),('license'),('insurance'),('vtv'))
          required(document_type)
        where not exists(
          select 1 from public.driver_documents d
          where d.driver_id=p.id
            and d.document_type=required.document_type
            and d.status='approved'
            and (required.document_type in ('dni_front','dni_back')
              or (d.expires_at is not null and d.expires_at>=current_date))
        )
      )
  )
$$;

revoke all on function public.driver_is_operational(uuid) from public;
grant execute on function public.driver_is_operational(uuid) to authenticated;

-- Sincroniza vencimientos y avisa una sola vez al conductor cuando queda
-- inhabilitado. Se llama al abrir la app, consultar ofertas y aceptar viajes.
create or replace function public.refresh_driver_compliance(
  p_driver_id uuid,
  p_notify boolean default true
) returns boolean language plpgsql security definer set search_path=public as $$
declare
  v_was_approved boolean;
  v_operational boolean;
  v_reason text;
begin
  if auth.uid() is not null and auth.uid()<>p_driver_id and not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  select is_approved into v_was_approved from public.profiles
  where id=p_driver_id and role='driver' for update;
  if not found then return false; end if;

  update public.driver_documents
    set status='expired'
  where driver_id=p_driver_id and document_type in ('license','insurance','vtv')
    and expires_at<current_date and status<>'expired';

  select public.driver_is_operational(p_driver_id) into v_operational;
  if v_was_approved and not v_operational then
    select string_agg(label, ', ') into v_reason from (
      select case d.document_type
        when 'license' then 'licencia'
        when 'insurance' then 'seguro'
        when 'vtv' then 'VTV/RTO'
        else d.document_type end as label
      from public.driver_documents d
      where d.driver_id=p_driver_id and d.document_type in ('license','insurance','vtv')
        and (d.expires_at is null or d.expires_at<current_date or d.status<>'approved')
      union all
      select 'habilitación municipal' where exists(
        select 1 from public.profiles p where p.id=p_driver_id
          and p.approved_until is not null and p.approved_until<now()
      )
    ) reasons;

    update public.profiles set is_approved=false,
      suspension_reason=coalesce(nullif(v_reason,''),'Documentación incompleta, vencida o pendiente'),
      updated_at=now()
    where id=p_driver_id;

    if p_notify and not exists(
      select 1 from public.driver_messages m where m.driver_id=p_driver_id
        and m.message_type='document' and m.created_at>now()-interval '24 hours'
        and m.title='Documentación requiere actualización'
    ) then
      insert into public.driver_messages(driver_id,title,body,message_type)
      values(p_driver_id,'Documentación requiere actualización',
        'No podés recibir viajes hasta regularizar: '||
        coalesce(nullif(v_reason,''),'documentación incompleta o pendiente')||
        '. Ingresá a Perfil > Documentación para ver el estado y reemplazar los archivos.',
        'document');
    end if;
  end if;
  return v_operational;
end $$;

revoke all on function public.refresh_driver_compliance(uuid,boolean) from public;
grant execute on function public.refresh_driver_compliance(uuid,boolean) to authenticated;

-- Última barrera: aunque una APK antigua intente aceptar directamente, la base
-- impide asignar el viaje a un conductor que dejó de estar habilitado.
create or replace function public.guard_trip_driver_eligibility()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='accepted'
    and (old.status is distinct from new.status or old.driver_id is distinct from new.driver_id)
    and not public.driver_is_operational(new.driver_id::uuid) then
    raise exception 'Conductor no habilitado para aceptar viajes';
  end if;
  return new;
end $$;

drop trigger if exists guard_trip_driver_eligibility on public.trips;
create trigger guard_trip_driver_eligibility
before update of status,driver_id on public.trips
for each row execute function public.guard_trip_driver_eligibility();

-- Configuración pública limitada para soporte. No expone otras opciones internas.
alter table public.system_settings
  add column if not exists text_value text,
  add column if not exists description text;

insert into public.system_settings(key,text_value,description)
values
  ('support_phone','','Teléfono/WhatsApp de soporte QuiacaGo'),
  ('emergency_phone','911','Número de emergencias mostrado en ambas aplicaciones')
on conflict(key) do nothing;

create or replace function public.get_public_support_config()
returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object(
    'support_phone',coalesce((select text_value from public.system_settings where key='support_phone'),''),
    'emergency_phone',coalesce((select text_value from public.system_settings where key='emergency_phone'),'911')
  )
$$;
grant execute on function public.get_public_support_config() to authenticated;

-- Eliminación autoservicio. Se bloquea si existe un viaje en curso y se borra
-- el usuario de Auth; las relaciones con ON DELETE CASCADE limpian sus datos.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path=public,auth as $$
declare v_user_id uuid:=auth.uid();
begin
  if v_user_id is null then raise exception 'Sesión vencida'; end if;
  if exists(
    select 1 from public.trips where
      (passenger_id=v_user_id or driver_id::text=v_user_id::text)
      and status in ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending')
  ) then raise exception 'No podés eliminar la cuenta mientras hay un viaje activo'; end if;
  if public.passenger_has_open_payment_dispute(v_user_id) then
    raise exception 'No podés eliminar la cuenta mientras soporte revisa un pago pendiente';
  end if;
  update public.driver_locations set is_online=false where driver_id::text=v_user_id::text;
  if to_regclass('public.trip_cancellation_events') is not null then
    execute 'delete from public.trip_cancellation_events
      where actor_id=$1 or affected_user_id=$1' using v_user_id;
  end if;
  delete from public.trips where passenger_id=v_user_id;
  update public.trip_ratings set driver_id='deleted'
    where driver_id=v_user_id::text;
  update public.trips set driver_id=null,driver_name='Cuenta eliminada',vehicle_info=null
    where driver_id::text=v_user_id::text;
  delete from auth.users where id=v_user_id;
end $$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
