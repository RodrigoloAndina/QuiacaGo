-- Calificación posterior al viaje. Ejecutar una vez en Supabase SQL Editor.
begin;

create table if not exists public.trip_ratings (
  id uuid primary key default gen_random_uuid(),
  trip_id text not null unique references public.trips(id) on delete cascade,
  passenger_id uuid not null references auth.users(id) on delete cascade,
  driver_id text not null,
  rating integer not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists trip_ratings_driver_idx
 on public.trip_ratings(driver_id,created_at desc);

alter table public.trip_ratings enable row level security;
drop policy if exists trip_ratings_read_participants on public.trip_ratings;
create policy trip_ratings_read_participants on public.trip_ratings for select
to authenticated using(
 passenger_id=auth.uid() or driver_id=auth.uid()::text or public.is_admin()
);

create or replace function public.rate_trip(
  p_trip_id text,p_rating integer,p_comment text default null
) returns public.trip_ratings
language plpgsql security definer set search_path=public as $$
declare
  trip_row public.trips;
  result public.trip_ratings;
begin
  if p_rating < 1 or p_rating > 5 then
    raise exception 'La calificación debe estar entre 1 y 5';
  end if;
  select * into trip_row from public.trips
  where id=p_trip_id and passenger_id=auth.uid() and status='completed';
  if trip_row.id is null then
    raise exception 'Sólo el pasajero puede calificar un viaje completado';
  end if;
  insert into public.trip_ratings(
    trip_id,passenger_id,driver_id,rating,comment
  ) values(
    trip_row.id,auth.uid(),trip_row.driver_id,p_rating,
    nullif(btrim(left(coalesce(p_comment,''),500)),'')
  )
  on conflict(trip_id) do update set
    rating=excluded.rating,comment=excluded.comment,updated_at=now()
  where public.trip_ratings.passenger_id=auth.uid()
  returning * into result;
  return result;
end $$;

revoke execute on function public.rate_trip(text,integer,text) from public,anon;
grant execute on function public.rate_trip(text,integer,text) to authenticated;

commit;
