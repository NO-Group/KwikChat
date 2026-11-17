-- ============================================================================
-- Private media bucket.
--
-- v0.1 stores voice notes here. Cloudflare R2 is the documented scale-out
-- (zero egress); the client only ever handles an opaque path + a short-lived
-- signed URL, so swapping the storage backend never touches the app.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  false,
  15728640, -- 15 MB hard cap per object
  array['audio/mp4', 'audio/webm', 'audio/ogg', 'image/webp', 'image/jpeg', 'video/mp4']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Uploads may only land in a folder named after the uploader's uid:
--   media/<uid>/<conversation>/<client-id>.m4a
drop policy if exists "media insert own folder" on storage.objects;
create policy "media insert own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Reads are signed-URL only. Paths are unguessable (uuid) and URLs expire.
-- Doubling as a participant check would need a join per object, so v0.1
-- accepts the opacity guarantee; see docs/CORRECTIONS.md item 6.
drop policy if exists "media read authenticated" on storage.objects;
create policy "media read authenticated" on storage.objects
  for select to authenticated
  using (bucket_id = 'media');

drop policy if exists "media delete own folder" on storage.objects;
create policy "media delete own folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
