-- Book covers are public to read. Uploads go through the Firebase-admin-verified
-- Edge Function; no anon/authenticated write policy is granted on storage.objects.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('book-covers', 'book-covers', true, 20971520,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Keep the Supabase RLS event-trigger helper callable by server roles only.
-- Its automatic table protection remains installed and enabled.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
