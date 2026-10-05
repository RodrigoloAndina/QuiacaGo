-- Base vacía solamente. Después ejecutar los scripts de PRODUCTION_SETUP.md.
-- IDs de viaje y conductor text conservan compatibilidad con los viajes TRIP-*.
begin;
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, name text, phone text not null unique, email text,
 role text not null default 'passenger' check(role in ('passenger','driver','admin')),
 is_approved boolean not null default false, approved_until timestamptz,
 suspension_reason text, licencia_expiration date, seguro_expiration date,
 vtv_expiration date, vehicle_info text, plate text unique, taxi_number text unique,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.driver_documents (
 id uuid primary key default gen_random_uuid(),
 driver_id uuid not null references public.profiles(id) on delete cascade,
 document_type text, storage_path text, status text not null default 'pending',
 expires_at date, review_note text, created_at timestamptz not null default now(),
 tipo text, titulo text, fecha_vencimiento date, documento_url text, estado text,
 unique(driver_id,document_type)
);
create table if not exists public.trips (
 id text primary key default gen_random_uuid()::text,
 passenger_id uuid references public.profiles(id) on delete set null,
 passenger_name text not null, passenger_phone text not null,
 driver_id text, driver_name text, vehicle_info text,
 pickup_address text not null, pickup_lat double precision not null,
 pickup_lng double precision not null, destination_address text not null,
 destination_lat double precision not null, destination_lng double precision not null,
 fare_amount numeric(10,2) not null check(fare_amount>=0), pin_code text not null,
 finish_code text, status text not null default 'requested',
 payment_method text not null default 'cash', payment_status text not null default 'pending',
 cancellation_reason text, created_at timestamptz not null default now(),
 accepted_at timestamptz, started_at timestamptz, finished_at timestamptz
);
create table if not exists public.driver_locations (
 driver_id text primary key, driver_name text not null, vehicle_info text not null,
 plate text not null, latitude double precision not null, longitude double precision not null,
 heading double precision not null default 0, is_online boolean not null default false,
 updated_at timestamptz not null default now()
);
create index if not exists trips_status_created_idx on public.trips(status,created_at desc);
create index if not exists trips_passenger_idx on public.trips(passenger_id,created_at desc);
create index if not exists trips_driver_idx on public.trips(driver_id,created_at desc);
alter table public.profiles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.trips enable row level security;
alter table public.driver_locations enable row level security;
commit;
