-- QuiacaGo - mediación de pagos en efectivo no recibidos.
-- Ejecutar antes de complete_trip_flow.sql y cancellation_management.sql.

create table if not exists public.payment_disputes (
  id uuid primary key default gen_random_uuid(),
  trip_id text not null unique references public.trips(id) on delete cascade,
  passenger_id uuid not null references public.profiles(id) on delete cascade,
  driver_id text not null,
  amount numeric(10,2) not null check(amount>=0),
  reason_code text not null check(reason_code in (
    'refused_to_pay','insufficient_cash','passenger_left','payment_disagreement','other'
  )),
  driver_notes text check(char_length(driver_notes)<=500),
  status text not null default 'open' check(status in ('open','resolved_paid','resolved_waived')),
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id),
  resolution_notes text check(char_length(resolution_notes)<=500)
);

create index if not exists payment_disputes_status_reported_idx
  on public.payment_disputes(status,reported_at desc);
create index if not exists payment_disputes_passenger_idx
  on public.payment_disputes(passenger_id,status);
create index if not exists payment_disputes_driver_idx
  on public.payment_disputes(driver_id,status);

alter table public.payment_disputes enable row level security;
drop policy if exists payment_disputes_participants_read on public.payment_disputes;
create policy payment_disputes_participants_read on public.payment_disputes
  for select to authenticated using(
    passenger_id=auth.uid() or driver_id=auth.uid()::text or public.is_admin()
  );
grant select on public.payment_disputes to authenticated;

create or replace function public.passenger_has_open_payment_dispute(p_passenger_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.payment_disputes
    where passenger_id=p_passenger_id and status='open')
$$;
revoke all on function public.passenger_has_open_payment_dispute(uuid) from public;
grant execute on function public.passenger_has_open_payment_dispute(uuid) to authenticated;

create or replace function public.report_cash_payment_not_received(
  p_trip_id text,p_reason_code text,p_notes text default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_trip public.trips;
begin
  if auth.uid() is null then raise exception 'Sesión vencida'; end if;
  if p_reason_code not in (
    'refused_to_pay','insufficient_cash','passenger_left','payment_disagreement','other'
  ) then raise exception 'Motivo inválido'; end if;

  select * into v_trip from public.trips where id::text=p_trip_id for update;
  if v_trip.id is null or v_trip.driver_id::text<>auth.uid()::text then
    raise exception 'El viaje no pertenece al conductor';
  end if;
  if v_trip.status<>'payment_pending' or v_trip.payment_status<>'pending'
    or v_trip.finish_code_used_at is null then
    raise exception 'El viaje ya fue pagado o no está listo para cobrar';
  end if;

  insert into public.payment_disputes(
    trip_id,passenger_id,driver_id,amount,reason_code,driver_notes
  ) values(
    v_trip.id::text,v_trip.passenger_id,v_trip.driver_id::text,v_trip.fare_amount,
    p_reason_code,nullif(btrim(left(coalesce(p_notes,''),500)),'')
  );

  update public.trips set status='completed',payment_status='disputed',finished_at=now()
  where id=v_trip.id;

  return jsonb_build_object(
    'success',true,
    'message','Reclamo registrado. Soporte revisará el caso y el conductor puede continuar trabajando.'
  );
end $$;

revoke all on function public.report_cash_payment_not_received(text,text,text) from public,anon;
grant execute on function public.report_cash_payment_not_received(text,text,text) to authenticated;

create or replace function public.get_my_open_payment_dispute()
returns table(
  id uuid,trip_id text,amount numeric,reason_code text,driver_notes text,
  reported_at timestamptz,status text
) language sql stable security definer set search_path=public as $$
  select d.id,d.trip_id,d.amount,d.reason_code,d.driver_notes,d.reported_at,d.status
  from public.payment_disputes d
  where d.passenger_id=auth.uid() and d.status='open'
  order by d.reported_at desc limit 1
$$;
revoke all on function public.get_my_open_payment_dispute() from public,anon;
grant execute on function public.get_my_open_payment_dispute() to authenticated;

create or replace function public.admin_list_payment_disputes()
returns table(
  id uuid,trip_id text,passenger_id uuid,passenger_name text,passenger_phone text,
  driver_id text,driver_name text,amount numeric,reason_code text,driver_notes text,
  pickup_address text,destination_address text,
  status text,reported_at timestamptz,resolved_at timestamptz,resolution_notes text
) language sql stable security definer set search_path=public as $$
  select d.id,d.trip_id,d.passenger_id,p.full_name,p.phone,d.driver_id,
    coalesce(t.driver_name,driver.full_name),d.amount,d.reason_code,d.driver_notes,
    t.pickup_address,t.destination_address,
    d.status,d.reported_at,d.resolved_at,d.resolution_notes
  from public.payment_disputes d
  join public.profiles p on p.id=d.passenger_id
  left join public.trips t on t.id::text=d.trip_id
  left join public.profiles driver on driver.id::text=d.driver_id
  where public.is_admin()
  order by (d.status='open') desc,d.reported_at desc
$$;
revoke all on function public.admin_list_payment_disputes() from public,anon;
grant execute on function public.admin_list_payment_disputes() to authenticated;

create or replace function public.resolve_payment_dispute(
  p_dispute_id uuid,p_resolution text,p_notes text
) returns void language plpgsql security definer set search_path=public as $$
declare v_dispute public.payment_disputes;
declare v_payment_status text;
begin
  if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
  if p_resolution not in ('paid','waived') then raise exception 'Resolución inválida'; end if;
  if nullif(btrim(p_notes),'') is null then raise exception 'La resolución debe incluir una nota'; end if;

  select * into v_dispute from public.payment_disputes
    where id=p_dispute_id for update;
  if v_dispute.id is null then raise exception 'Reclamo inexistente'; end if;
  if v_dispute.status<>'open' then raise exception 'El reclamo ya fue resuelto'; end if;

  v_payment_status:=case when p_resolution='paid' then 'paid' else 'waived' end;
  update public.payment_disputes set
    status=case when p_resolution='paid' then 'resolved_paid' else 'resolved_waived' end,
    resolved_at=now(),resolved_by=auth.uid(),
    resolution_notes=btrim(left(p_notes,500))
  where id=p_dispute_id;
  update public.trips set payment_status=v_payment_status,
    payment_confirmed_at=case when p_resolution='paid' then now() else payment_confirmed_at end
  where id::text=v_dispute.trip_id;

  insert into public.driver_messages(driver_id,title,body,message_type,created_by)
  values(v_dispute.driver_id::uuid,'Reclamo de pago resuelto',
    case when p_resolution='paid'
      then 'Soporte confirmó el pago del viaje.'
      else 'Soporte anuló la deuda del pasajero para este viaje.' end||
      ' Resolución: '||btrim(left(p_notes,500)),
    'general',auth.uid());
end $$;

revoke all on function public.resolve_payment_dispute(uuid,text,text) from public,anon;
grant execute on function public.resolve_payment_dispute(uuid,text,text) to authenticated;
