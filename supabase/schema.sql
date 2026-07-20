-- ========================================================
-- QUIACAGO - ESQUEMA DE BASE DE DATOS POSTGRESQL SUPABASE
-- La Quiaca, Jujuy - Plataforma de Taxis Habilitados
-- ========================================================

-- Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUMS DE DOMINIO
CREATE TYPE user_role AS ENUM ('PASSENGER', 'DRIVER', 'ADMIN');
CREATE TYPE driver_status AS ENUM ('OFFLINE', 'AVAILABLE', 'ON_TRIP');
CREATE TYPE trip_status AS ENUM ('REQUESTED', 'ACCEPTED', 'ARRIVING', 'WAITING_PASSENGER', 'STARTED', 'FINISHED', 'CANCELLED');
CREATE TYPE document_status AS ENUM ('APPROVED', 'PENDING', 'EXPIRED');

-- 2. TABLA DE PERFILES (PASAJEROS Y CONDUCTORES HABILITADOS)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(30) UNIQUE NOT NULL,
    rol user_role NOT NULL DEFAULT 'PASSENGER',
    estado driver_status DEFAULT 'OFFLINE',
    calificacion NUMERIC(3, 2) DEFAULT 5.00,
    foto_url TEXT,
    is_approved BOOLEAN DEFAULT FALSE, -- Regla de Negocio: Conductor requiere aprobación de admin
    dias_habilitacion INTEGER DEFAULT 30, -- Cantidad de días habilitado (30, 60, 365)
    fecha_vencimiento_habilitacion TIMESTAMP WITH TIME ZONE, -- Fecha exacta de corte de acceso
    motivo_inhabilitacion TEXT DEFAULT 'Falta de pago de cuota mensual municipal', -- Mensaje personalizado en pantalla
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. TABLA DE VEHÍCULOS HABILITADOS
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    color VARCHAR(30) NOT NULL,
    patente VARCHAR(15) UNIQUE NOT NULL,
    numero_interno VARCHAR(20) NOT NULL, -- Int. 042, etc.
    is_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. TABLA DE DOCUMENTACIÓN DEL CONDUCTOR
CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL, -- 'MUNICIPAL', 'LICENSE', 'INSURANCE', 'VTV', 'DNI'
    titulo VARCHAR(100) NOT NULL,
    estado document_status DEFAULT 'PENDING',
    fecha_vencimiento DATE NOT NULL,
    documento_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 5. TABLA DE VIAJES EN TIEMPO REAL
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    origen VARCHAR(255) NOT NULL,
    destino VARCHAR(255) NOT NULL,
    origen_lat NUMERIC(10, 7) NOT NULL,
    origen_lng NUMERIC(10, 7) NOT NULL,
    destino_lat NUMERIC(10, 7) NOT NULL,
    destino_lng NUMERIC(10, 7) NOT NULL,
    tarifa NUMERIC(10, 2) NOT NULL,
    estado trip_status DEFAULT 'REQUESTED' NOT NULL,
    codigo_seguridad VARCHAR(4) NOT NULL, -- PIN obligatorio de 4 dígitos (Ej: '4821')
    metodo_pago VARCHAR(30) DEFAULT 'EFECTIVO',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE
);

-- 6. TABLA DE GEOLOCALIZACIÓN EN TIEMPO REAL
CREATE TABLE IF NOT EXISTS public.driver_locations (
    driver_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    lat NUMERIC(10, 7) NOT NULL,
    lng NUMERIC(10, 7) NOT NULL,
    heading NUMERIC(5, 2) DEFAULT 0.00,
    is_online BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 7. HABILITAR REALTIME EN WEBSOCKETS SUPABASE
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acceso publico perfiles" ON public.profiles FOR ALL USING (true);
CREATE POLICY "Acceso publico vehiculos" ON public.vehicles FOR ALL USING (true);
CREATE POLICY "Acceso publico documentos" ON public.driver_documents FOR ALL USING (true);
CREATE POLICY "Acceso publico viajes" ON public.trips FOR ALL USING (true);
CREATE POLICY "Acceso publico ubicaciones" ON public.driver_locations FOR ALL USING (true);
