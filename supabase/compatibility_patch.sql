-- Ejecutar antes de volver a correr los scripts que fallaron.
begin;
alter table public.trips add column if not exists passenger_paid_at timestamptz;
alter table public.system_settings
  add column if not exists text_value text,
  add column if not exists description text;
alter table public.profiles
  alter column licencia_expiration type date using case when licencia_expiration is null or btrim(licencia_expiration::text)='' then null when btrim(licencia_expiration::text) ~ '^\d{4}-\d{2}-\d{2}$' then btrim(licencia_expiration::text)::date else null end,
  alter column seguro_expiration type date using case when seguro_expiration is null or btrim(seguro_expiration::text)='' then null when btrim(seguro_expiration::text) ~ '^\d{4}-\d{2}-\d{2}$' then btrim(seguro_expiration::text)::date else null end,
  alter column vtv_expiration type date using case when vtv_expiration is null or btrim(vtv_expiration::text)='' then null when btrim(vtv_expiration::text) ~ '^\d{4}-\d{2}-\d{2}$' then btrim(vtv_expiration::text)::date else null end;
commit;
