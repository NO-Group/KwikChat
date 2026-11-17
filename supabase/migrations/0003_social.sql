-- ============================================================================
-- 0003 — comments feed, blocking by handle
--
-- Adds the read model the app needs for threaded discussion, and makes the
-- "block and report" flow actually block (v0.1 filed the report but had no
-- way to resolve a handle to a user id from the client).
-- ============================================================================

create or replace view public.joint_comment_feed
with (security_invoker = true) as
select
  c.id,
  c.post_id,
  c.parent_comment_id,
  c.body,
  c.hype_count,
  c.fade_count,
  c.created_at,
  pr.username as author_username
from joint_comments c
join profiles pr on pr.id = c.author_id
where c.deleted_at is null;

grant select on public.joint_comment_feed to authenticated;

-- Block by handle: the client only ever knows the @username it is looking at.
create or replace function public.block_user(p_username text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  target uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select id into target from public.profiles where username = lower(trim(p_username));
  if target is null then raise exception 'not_found'; end if;
  if target = me then raise exception 'invalid_username' using detail = 'cannot block yourself'; end if;

  insert into public.blocks (blocker_id, blocked_id)
  values (me, target)
  on conflict (blocker_id, blocked_id) do nothing;
end $$;

create or replace function public.unblock_user(p_username text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  target uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select id into target from public.profiles where username = lower(trim(p_username));
  if target is null then raise exception 'not_found'; end if;

  delete from public.blocks where blocker_id = me and blocked_id = target;
end $$;

grant execute on function public.block_user(text) to authenticated;
grant execute on function public.unblock_user(text) to authenticated;
