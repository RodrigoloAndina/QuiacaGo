-- Restaura permisos de legajos después del endurecimiento de producción.
-- Seguro para ejecutar más de una vez.
begin;

grant usage on schema public to authenticated;
grant select on table public.driver_documents to authenticated;
-- PostgREST necesita privilegios de tabla para INSERT/UPDATE. El trigger
-- protector que sigue limita efectivamente qué columnas puede cambiar un
-- conductor; los administradores conservan la edición del legajo.
grant insert, update on table public.driver_documents to authenticated;

create or replace function public.protect_document_review() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida';
  end if;

  if not public.is_admin() then
    if new.driver_id <> auth.uid()
      or not exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.role = 'driver'
          and p.deletion_requested_at is null
      ) then
      raise exception 'Legajo no autorizado';
    end if;

    if new.storage_path is null
      or split_part(new.storage_path, '/', 1) <> auth.uid()::text
      or new.storage_path like '%..%' then
      raise exception 'Archivo fuera del legajo';
    end if;

    if tg_op = 'INSERT' then
      new.status := 'pending';
      new.review_note := null;
      new.tipo := null;
      new.titulo := null;
      new.fecha_vencimiento := null;
      new.documento_url := null;
      new.estado := null;
    else
      -- El dueño sólo puede reemplazar el archivo o su vencimiento. Los datos
      -- de revisión, identidad de fila y campos heredados quedan protegidos.
      new.id := old.id;
      new.driver_id := old.driver_id;
      new.document_type := old.document_type;
      new.created_at := old.created_at;
      new.tipo := old.tipo;
      new.titulo := old.titulo;
      new.fecha_vencimiento := old.fecha_vencimiento;
      new.documento_url := old.documento_url;
      new.estado := old.estado;

      if new.storage_path is distinct from old.storage_path
        or new.expires_at is distinct from old.expires_at then
        new.status := 'pending';
        new.review_note := null;
      else
        new.status := old.status;
        new.review_note := old.review_note;
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists protect_document_review on public.driver_documents;
create trigger protect_document_review
before insert or update on public.driver_documents
for each row execute function public.protect_document_review();

alter table public.driver_documents enable row level security;

drop policy if exists documents_owner on public.driver_documents;
drop policy if exists driver_documents_owner_select on public.driver_documents;
drop policy if exists driver_documents_owner_insert on public.driver_documents;
drop policy if exists driver_documents_owner_update on public.driver_documents;
drop policy if exists documents_admin_read on public.driver_documents;
drop policy if exists documents_admin_insert on public.driver_documents;
drop policy if exists documents_admin_update on public.driver_documents;

create policy driver_documents_owner_select
  on public.driver_documents for select to authenticated
  using (driver_id = auth.uid());

create policy driver_documents_owner_insert
  on public.driver_documents for insert to authenticated
  with check (
    driver_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'driver'
    )
  );

create policy driver_documents_owner_update
  on public.driver_documents for update to authenticated
  using (driver_id = auth.uid())
  with check (driver_id = auth.uid());

create policy documents_admin_read
  on public.driver_documents for select to authenticated
  using (public.is_admin());

create policy documents_admin_insert
  on public.driver_documents for insert to authenticated
  with check (public.is_admin());

create policy documents_admin_update
  on public.driver_documents for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Storage necesita privilegios SQL y políticas RLS. Los archivos permanecen
-- privados y limitados al dueño del legajo o a un administrador autenticado.
grant select, insert, update on table storage.objects to authenticated;

drop policy if exists driver_documents_upload on storage.objects;
drop policy if exists driver_documents_update on storage.objects;
drop policy if exists driver_documents_read_own on storage.objects;
drop policy if exists driver_documents_read_admin on storage.objects;
drop policy if exists driver_documents_admin_upload on storage.objects;
drop policy if exists driver_documents_admin_update on storage.objects;

create policy driver_documents_upload
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy driver_documents_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy driver_documents_read_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy driver_documents_read_admin
  on storage.objects for select to authenticated
  using (bucket_id = 'driver-documents' and public.is_admin());

create policy driver_documents_admin_upload
  on storage.objects for insert to authenticated
  with check (bucket_id = 'driver-documents' and public.is_admin());

create policy driver_documents_admin_update
  on storage.objects for update to authenticated
  using (bucket_id = 'driver-documents' and public.is_admin())
  with check (bucket_id = 'driver-documents' and public.is_admin());

commit;

-- Las seis comprobaciones deben devolver OK.
select componente, estado
from (
  values
    ('driver_documents SELECT', case when has_table_privilege('authenticated', 'public.driver_documents', 'SELECT') then 'OK' else 'FALTA' end),
    ('driver_documents INSERT', case when has_table_privilege('authenticated', 'public.driver_documents', 'INSERT') then 'OK' else 'FALTA' end),
    ('driver_documents UPDATE', case when has_table_privilege('authenticated', 'public.driver_documents', 'UPDATE') then 'OK' else 'FALTA' end),
    ('storage.objects SELECT', case when has_table_privilege('authenticated', 'storage.objects', 'SELECT') then 'OK' else 'FALTA' end),
    ('storage.objects INSERT', case when has_table_privilege('authenticated', 'storage.objects', 'INSERT') then 'OK' else 'FALTA' end),
    ('storage.objects UPDATE', case when has_table_privilege('authenticated', 'storage.objects', 'UPDATE') then 'OK' else 'FALTA' end)
) as checks(componente, estado);
