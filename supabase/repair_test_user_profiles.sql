-- Repara usuarios de prueba creados en Supabase Auth cuando faltaba el trigger
-- que genera public.profiles. Es idempotente: puede ejecutarse más de una vez.
begin;

-- Garantiza que los próximos usuarios también creen su perfil.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Recupera los perfiles de las cuentas de prueba ya existentes sin cambiar
-- aprobaciones o información de perfiles que ya hayan sido creados.
insert into public.profiles (
  id,
  full_name,
  name,
  phone,
  email,
  role,
  is_approved,
  vehicle_info,
  plate,
  taxi_number,
  created_at,
  updated_at
)
select
  u.id,
  left(coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'), ''), 'Usuario de prueba'), 120),
  left(coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'), ''), 'Usuario de prueba'), 120),
  coalesce(nullif(btrim(u.raw_user_meta_data->>'phone'), ''), u.phone, u.id::text),
  u.email,
  case
    when u.raw_user_meta_data->>'role' = 'driver' then 'driver'
    else 'passenger'
  end,
  case
    when u.raw_user_meta_data->>'role' = 'driver' then false
    else true
  end,
  case when u.raw_user_meta_data->>'role' = 'driver'
    then coalesce(nullif(btrim(u.raw_user_meta_data->>'vehicle_info'), ''), 'Vehículo de prueba')
  end,
  case when u.raw_user_meta_data->>'role' = 'driver'
    then nullif(upper(btrim(u.raw_user_meta_data->>'plate')), '')
  end,
  case when u.raw_user_meta_data->>'role' = 'driver'
    then nullif(btrim(u.raw_user_meta_data->>'taxi_number'), '')
  end,
  coalesce(u.created_at, now()),
  now()
from auth.users u
where u.email like '%@pruebas.quiacago.com.ar'
  and not exists (
    select 1 from public.profiles p where p.id = u.id
  );

commit;

-- Debe devolver las diez cuentas (cinco pasajeros y cinco conductores).
select
  p.full_name,
  p.email,
  p.role,
  p.is_approved,
  case
    when p.role = 'driver' then 'Debe cargar 5 documentos y ser aprobado'
    else 'Listo para iniciar sesión'
  end as siguiente_paso
from public.profiles p
where p.email like '%@pruebas.quiacago.com.ar'
order by p.role, p.email;
