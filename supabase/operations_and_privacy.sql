-- Aplicar después de production_hardening.sql.
begin;
create table if not exists public.payment_dispute_messages (
 id uuid primary key default gen_random_uuid(),
 dispute_id uuid not null references public.payment_disputes(id) on delete cascade,
 author_id uuid references public.profiles(id) on delete set null,
 author_role text not null check(author_role in ('passenger','driver','admin')),
 body text not null check(char_length(body) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index if not exists dispute_messages_conversation_idx on public.payment_dispute_messages(dispute_id,created_at);
alter table public.payment_dispute_messages enable row level security;
create table if not exists public.payment_dispute_audit (
 id uuid primary key default gen_random_uuid(),dispute_id uuid references public.payment_disputes(id) on delete set null,
 actor_id uuid references public.profiles(id) on delete set null,action text not null,
 detail text not null,created_at timestamptz not null default now()
);
alter table public.payment_dispute_audit enable row level security;
drop policy if exists dispute_audit_admin on public.payment_dispute_audit;
create policy dispute_audit_admin on public.payment_dispute_audit for select to authenticated using(public.is_admin());
grant select on public.payment_dispute_audit to authenticated;
revoke insert,update,delete on public.payment_disputes,public.payment_dispute_messages,public.payment_dispute_audit from anon,authenticated;

create or replace function public.get_payment_dispute_messages(p_dispute_id uuid) returns jsonb
language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at),'[]'::jsonb) from (
  select x.id,x.author_role,x.body,x.created_at from public.payment_dispute_messages x
  join public.payment_disputes d on d.id=x.dispute_id where d.id=p_dispute_id
   and (d.passenger_id=auth.uid() or d.driver_id=auth.uid()::text or public.is_admin())
  order by x.created_at desc limit 100
 ) m
$$;
create or replace function public.add_payment_dispute_message(p_dispute_id uuid,p_message text) returns uuid
language plpgsql security definer set search_path=public as $$
declare d public.payment_disputes; v_id uuid; v_role text;
begin
 select * into d from public.payment_disputes where id=p_dispute_id for update;
 if d.id is null or not(coalesce(d.passenger_id=auth.uid(),false) or coalesce(d.driver_id=auth.uid()::text,false) or public.is_admin()) then
   raise exception 'Reclamo no autorizado'; end if;
 if d.status<>'open' then raise exception 'El reclamo ya tiene una resolución'; end if;
 if nullif(btrim(p_message),'') is null or char_length(p_message)>1000 then raise exception 'Escribí entre 1 y 1000 caracteres'; end if;
 if (select count(*) from public.payment_dispute_messages where dispute_id=p_dispute_id and author_id=auth.uid()
     and created_at>now()-interval '1 minute')>=5 then raise exception 'Esperá un minuto antes de enviar más mensajes'; end if;
 v_role:=case when public.is_admin() then 'admin' when d.passenger_id=auth.uid() then 'passenger' else 'driver' end;
 insert into public.payment_dispute_messages(dispute_id,author_id,author_role,body)
 values(p_dispute_id,auth.uid(),v_role,btrim(p_message)) returning id into v_id;
 return v_id;
end $$;
create or replace function public.get_my_payment_disputes() returns jsonb
language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(to_jsonb(d) order by d.reported_at desc),'[]'::jsonb) from (
  select id,trip_id,amount,reason_code,driver_notes,status,reported_at,resolved_at,resolution_notes
  from public.payment_disputes where passenger_id=auth.uid() or driver_id=auth.uid()::text
  order by reported_at desc limit 50
 ) d
$$;
drop function if exists public.admin_list_payment_disputes();
drop function if exists public.admin_list_payment_disputes(integer);
create or replace function public.admin_list_payment_disputes(p_limit integer default 100,p_offset integer default 0)
returns table(id uuid,trip_id text,passenger_id uuid,passenger_name text,passenger_phone text,
 driver_id text,driver_name text,amount numeric,reason_code text,driver_notes text,
 pickup_address text,destination_address text,status text,reported_at timestamptz,resolved_at timestamptz,
 resolution_notes text,passenger_paid_at timestamptz)
language sql stable security definer set search_path=public as $$
 select d.id,d.trip_id,d.passenger_id,p.full_name,p.phone,d.driver_id,coalesce(t.driver_name,dr.full_name),
 d.amount,d.reason_code,d.driver_notes,t.pickup_address,t.destination_address,d.status,d.reported_at,d.resolved_at,d.resolution_notes,t.passenger_paid_at
 from public.payment_disputes d join public.profiles p on p.id=d.passenger_id
 left join public.trips t on t.id=d.trip_id left join public.profiles dr on dr.id::text=d.driver_id
 where public.is_admin() order by (d.status='open') desc,d.reported_at desc
 limit greatest(1,least(p_limit,100)) offset greatest(0,least(p_offset,100000))
$$;
create or replace function public.resolve_payment_dispute(p_dispute_id uuid,p_resolution text,p_notes text) returns void
language plpgsql security definer set search_path=public as $$
declare d public.payment_disputes;
begin
 if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
 if p_resolution is null or p_resolution not in ('paid','waived') then raise exception 'Resolución inválida'; end if;
 if nullif(btrim(p_notes),'') is null or char_length(p_notes)>500 then raise exception 'La resolución requiere una nota de hasta 500 caracteres'; end if;
 select * into d from public.payment_disputes where id=p_dispute_id for update;
 if d.id is null or d.status<>'open' then raise exception 'El reclamo no existe o ya fue resuelto'; end if;
 update public.payment_disputes set status=case when p_resolution='paid' then 'resolved_paid' else 'resolved_waived' end,
   resolved_at=now(),resolved_by=auth.uid(),resolution_notes=btrim(p_notes) where id=p_dispute_id;
 update public.trips set payment_status=p_resolution,
   payment_confirmed_at=case when p_resolution='paid' then now() else null end where id=d.trip_id;
 insert into public.payment_dispute_audit(dispute_id,actor_id,action,detail)
 values(p_dispute_id,auth.uid(),p_resolution,btrim(p_notes));
 insert into public.payment_dispute_messages(dispute_id,author_id,author_role,body)
 values(p_dispute_id,auth.uid(),'admin','Resolución: '||btrim(p_notes));
 insert into public.driver_messages(driver_id,title,body,message_type,created_by)
 select p.id,'Reclamo de pago resuelto','Soporte resolvió el reclamo: '||btrim(p_notes),'general',auth.uid()
 from public.profiles p where p.id::text=d.driver_id;
end $$;

create or replace function public.get_my_driver_stats() returns jsonb
language sql stable security definer set search_path=public as $$
 with bounds as (select date_trunc('day',now() at time zone 'America/Argentina/Jujuy') at time zone 'America/Argentina/Jujuy' d,
 date_trunc('week',now() at time zone 'America/Argentina/Jujuy') at time zone 'America/Argentina/Jujuy' w,
 date_trunc('month',now() at time zone 'America/Argentina/Jujuy') at time zone 'America/Argentina/Jujuy' m),
 stats as (select count(*) filter(where t.finished_at>=b.d) trips_today,
 coalesce(sum(t.fare_amount) filter(where t.finished_at>=b.d),0) earnings_today,
 count(*) filter(where t.finished_at>=b.w) trips_week,coalesce(sum(t.fare_amount) filter(where t.finished_at>=b.w),0) earnings_week,
 count(*) filter(where t.finished_at>=b.m) trips_month,coalesce(sum(t.fare_amount) filter(where t.finished_at>=b.m),0) earnings_month
 from public.trips t cross join bounds b where t.driver_id=auth.uid()::text and t.status='completed' and t.payment_status='paid'
 and t.finished_at>=least(b.w,b.m)),
 ratings as (select coalesce(round(avg(rating),2),0) rating_average,count(*) rating_count from public.trip_ratings where driver_id=auth.uid()::text)
 select to_jsonb(stats)||to_jsonb(ratings) from stats cross join ratings
$$;
create index if not exists trips_driver_finished_paid_idx on public.trips(driver_id,finished_at desc)
 where status='completed' and payment_status='paid';
create index if not exists trips_active_passenger_idx on public.trips(passenger_id,created_at desc)
 where status in ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending');
create index if not exists trips_active_driver_idx on public.trips(driver_id)
 where status in ('accepted','arrived','in_progress','awaiting_finish_code','payment_pending');

create or replace function public.admin_operations_summary() returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare v_day timestamptz:=date_trunc('day',now() at time zone 'America/Argentina/Jujuy') at time zone 'America/Argentina/Jujuy'; v_result jsonb;
begin
 if not public.is_admin() then raise exception 'Acceso administrativo requerido'; end if;
 select jsonb_build_object(
 'passengers_total',(select count(*) from public.profiles where role='passenger'),
 'drivers_total',(select count(*) from public.profiles where role='driver'),
 'drivers_eligible',(select count(*) from public.profiles where role='driver' and public.driver_is_operational(id)),
 'trips_today',(select count(*) from public.trips where created_at>=v_day),
 'trips_active',(select count(*) from public.trips where status in ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending')),
 'trips_cancelled_today',(select count(*) from public.trips where status='cancelled' and cancelled_at>=v_day),
 'demand_by_hour',(select jsonb_agg(jsonb_build_object('hour',h*2,'count',(select count(*) from public.trips t
   where t.created_at>=v_day+(h*2)*interval '1 hour' and t.created_at<v_day+(h*2+2)*interval '1 hour')) order by h)
   from generate_series(0,11) h),
 'recent_activity',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
   select title,message as description,created_at from public.admin_notifications order by created_at desc limit 8) x)
 ) into v_result; return v_result;
end $$;
drop function if exists public.admin_list_users();
create or replace function public.admin_list_users(p_limit integer default 51,p_offset integer default 0)
returns table(id uuid,full_name text,phone text,email text,role text,created_at timestamptz,is_approved boolean,
 approved_until timestamptz,account_suspended_until timestamptz,account_suspension_reason text,
 trips_total bigint,trips_completed bigint,cancellations_total bigint,cancellations_30d bigint,last_cancellation_at timestamptz)
language sql stable security definer set search_path=public as $$
 with page as (select p.* from public.profiles p where public.is_admin() order by p.created_at desc,p.id
 limit greatest(1,least(p_limit,100)) offset greatest(0,least(p_offset,100000)))
 select p.id,p.full_name,p.phone,p.email,p.role,p.created_at,p.is_approved,p.approved_until,
 p.account_suspended_until,p.account_suspension_reason,t.n,t.completed,c.n,c.recent,c.last_at from page p
 cross join lateral(select count(*) n,count(*) filter(where x.status='completed') completed from public.trips x
   where x.passenger_id=p.id or x.driver_id=p.id::text) t
 cross join lateral(select count(*) n,count(*) filter(where x.created_at>=now()-interval '30 days') recent,max(x.created_at) last_at
   from public.trip_cancellation_events x where x.actor_id=p.id) c
 order by p.created_at desc,p.id
$$;

-- Eliminación: reservar primero el perfil evita nuevos viajes durante la limpieza.
-- El borrado físico de objetos y de Auth se realiza en la Edge Function, nunca SQL.
create or replace function public.request_my_account_deletion() returns void
language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Sesión vencida'; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if not found then return; end if;
 if public.is_admin() then raise exception 'Transferí la administración antes de eliminar esta cuenta'; end if;
 if exists(select 1 from public.trips where (passenger_id=auth.uid() or driver_id=auth.uid()::text)
   and status in ('requested','accepted','arrived','in_progress','awaiting_finish_code','payment_pending')) then
   raise exception 'Finalizá el viaje activo antes de eliminar la cuenta'; end if;
 if exists(select 1 from public.payment_disputes where (passenger_id=auth.uid() or driver_id=auth.uid()::text) and status='open') then
   raise exception 'Soporte debe resolver el reclamo abierto antes de eliminar la cuenta'; end if;
 update public.profiles set deletion_requested_at=coalesce(deletion_requested_at,now()) where id=auth.uid();
 update public.driver_locations set is_online=false where driver_id=auth.uid()::text;
end $$;
create or replace function public.account_deletion_objects(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path=public,storage as $$
begin
 if not exists(select 1 from public.profiles where id=p_user_id and deletion_requested_at is not null) then
   raise exception 'La cuenta no solicitó eliminación'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('bucket_id',o.bucket_id,'name',o.name)),'[]'::jsonb)
 from storage.objects o where o.owner_id=p_user_id::text
 or (o.bucket_id='driver-documents' and split_part(o.name,'/',1)=p_user_id::text));
end $$;
create or replace function public.finish_account_data_deletion(p_user_id uuid) returns void
language plpgsql security definer set search_path=public,storage as $$
begin
 perform 1 from public.profiles where id=p_user_id and deletion_requested_at is not null for update;
 if not found then raise exception 'La cuenta no solicitó eliminación'; end if;
 if exists(select 1 from storage.objects where owner_id=p_user_id::text
   or (bucket_id='driver-documents' and split_part(name,'/',1)=p_user_id::text)) then
   raise exception 'Aún existen archivos: reintentá la eliminación'; end if;
 -- Se conserva la contabilidad del otro participante, sin identidad/contacto/recorrido del solicitante.
 delete from public.trip_cancellation_events where actor_id=p_user_id or affected_user_id=p_user_id;
 delete from public.trip_ratings where passenger_id=p_user_id or driver_id=p_user_id::text;
 delete from public.payment_dispute_messages where author_id=p_user_id;
 delete from public.payment_disputes where passenger_id=p_user_id or driver_id=p_user_id::text;
 update public.driver_messages set created_by=null where created_by=p_user_id;
 update public.admin_notifications set read_by=null where read_by=p_user_id;
 update public.fare_settings set updated_by=null where updated_by=p_user_id;
 update public.profiles set account_suspended_by=null where account_suspended_by=p_user_id;
 update public.trips set passenger_id=case when passenger_id=p_user_id then null else passenger_id end,
   driver_id=case when driver_id=p_user_id::text then null else driver_id end,
   passenger_name=case when passenger_id=p_user_id then 'Cuenta eliminada' else passenger_name end,
   passenger_phone=case when passenger_id=p_user_id then '' else passenger_phone end,
   driver_name=case when driver_id=p_user_id::text then 'Cuenta eliminada' else driver_name end,
   vehicle_info=case when driver_id=p_user_id::text then null else vehicle_info end,
   pickup_address='Recorrido eliminado',destination_address='Recorrido eliminado',
   pickup_lat=0,pickup_lng=0,destination_lat=0,destination_lng=0,
   cancelled_by=case when cancelled_by=p_user_id then null else cancelled_by end,
   cancellation_reason=null
 where passenger_id=p_user_id or driver_id=p_user_id::text;
 delete from public.driver_locations where driver_id=p_user_id::text;
 delete from public.driver_documents where driver_id=p_user_id;
 delete from public.passenger_private_data where passenger_id=p_user_id;
 -- Auth deleteUser elimina el perfil por FK CASCADE; sólo se minimizan datos antes.
 update public.profiles set full_name='Cuenta eliminada',name='Cuenta eliminada',phone='deleted.'||p_user_id,
   email=null,plate=null,taxi_number=null,vehicle_info=null,is_approved=false where id=p_user_id;
end $$;
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path=public as $$
begin raise exception 'Actualizá la aplicación para eliminar tu cuenta y archivos de forma segura'; end $$;

revoke all on function public.account_deletion_objects(uuid),public.finish_account_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_objects(uuid),public.finish_account_data_deletion(uuid) to service_role;
revoke all on function public.get_payment_dispute_messages(uuid),public.add_payment_dispute_message(uuid,text),
 public.get_my_payment_disputes(),public.admin_list_payment_disputes(integer,integer),public.get_my_driver_stats(),
 public.admin_operations_summary(),public.admin_list_users(integer,integer),public.request_my_account_deletion() from public,anon;
grant execute on function public.get_payment_dispute_messages(uuid),public.add_payment_dispute_message(uuid,text),
 public.get_my_payment_disputes(),public.admin_list_payment_disputes(integer,integer),public.get_my_driver_stats(),
 public.admin_operations_summary(),public.admin_list_users(integer,integer),public.request_my_account_deletion() to authenticated;
commit;
