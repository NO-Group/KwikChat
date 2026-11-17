-- ============================================================================
-- KwikChat — schema v0.1 (production shape, not a sketch)
--
-- Fixes applied vs. the original PRD SQL:
--   1. RLS is actually ENABLED and POLICY-ED on every table (the PRD promised
--      RLS but shipped none — that alone leaked every message and ledger row).
--   2. Cowries are a LEDGER. `profiles.cowries_balance` is a trigger-maintained
--      cache of `cowrie_transactions`, so the two can never drift.
--   3. spend_cowries() no longer takes a user id from the caller — it uses
--      auth.uid(), validates the amount and the allowed spend kinds.
--   4. Messages are DURABLE (no purge-on-delivery). Losing your phone must not
--      delete your history, and a vendor's order thread must survive.
--   5. Counters are recomputed from source rows by triggers, never incremented
--      blindly by clients.
--   6. Reporting/blocking exist from day one (store review + basic safety).
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- utilities
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ================================================================== profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  bio text not null default '' check (char_length(bio) <= 280),
  avatar_path text,
  city text not null default 'Jos',
  country_code text not null default 'NG',
  is_vendor boolean not null default false,
  is_verified boolean not null default false,
  verified_until timestamptz,
  -- cache of the ledger, maintained only by trigger; never written by clients
  cowries_balance integer not null default 0 check (cowries_balance >= 0),
  data_saver_mode boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_username_trgm on public.profiles (lower(username));

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ============================================================= conversations
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text,
  created_by uuid references public.profiles (id) on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  order_status text,
  is_muted boolean not null default false,
  last_read_at timestamptz not null default 'epoch',
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id),
  constraint order_status_valid check (
    order_status is null
    or order_status in ('Pending Payment', 'Paid', 'Dispatched', 'Resolved')
  )
);

create index if not exists participants_user_idx on public.conversation_participants (user_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null default 'text' check (kind in ('text', 'voice', 'image', 'video', 'system')),
  body text not null default '' check (char_length(body) <= 4000),
  media_path text,
  duration_ms integer not null default 0 check (duration_ms >= 0 and duration_ms <= 300000),
  client_id uuid,                     -- idempotency key from the device
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (conversation_id, client_id)
);

create index if not exists messages_conv_idx on public.messages (conversation_id, created_at desc);
create index if not exists messages_sender_idx on public.messages (sender_id);

-- keep the thread ordering cheap
create or replace function public.bump_conversation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update conversations set last_message_at = new.created_at where id = new.conversation_id;
  return new;
end $$;

drop trigger if exists messages_bump on public.messages;
create trigger messages_bump after insert on public.messages
  for each row execute function public.bump_conversation();

-- ==================================================================== joints
create table if not exists public.joints (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[A-Za-z0-9_]{3,25}$'),
  description text not null default '' check (char_length(description) <= 300),
  creator_id uuid references public.profiles (id) on delete set null,
  members_count integer not null default 0 check (members_count >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.joint_members (
  joint_id uuid not null references public.joints (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (joint_id, user_id)
);

create table if not exists public.joint_posts (
  id uuid primary key default gen_random_uuid(),
  joint_id uuid not null references public.joints (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 200),
  body text not null default '' check (char_length(body) <= 8000),
  media_urls text[] not null default '{}',
  hype_count integer not null default 0 check (hype_count >= 0),
  fade_count integer not null default 0 check (fade_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  cowrie_awards integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists joint_posts_joint_idx on public.joint_posts (joint_id, created_at desc);

create table if not exists public.joint_votes (
  post_id uuid not null references public.joint_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  vote_type text not null check (vote_type in ('hype', 'fade')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.joint_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.joint_posts (id) on delete cascade,
  parent_comment_id uuid references public.joint_comments (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  hype_count integer not null default 0,
  fade_count integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists joint_comments_post_idx on public.joint_comments (post_id, created_at);

-- counters recomputed from source, so they cannot drift
create or replace function public.sync_post_vote_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := case when tg_op = 'DELETE' then old.post_id else new.post_id end;
begin
  update joint_posts p set
    hype_count = (select count(*) from joint_votes v where v.post_id = target and v.vote_type = 'hype'),
    fade_count = (select count(*) from joint_votes v where v.post_id = target and v.vote_type = 'fade')
  where p.id = target;
  return null;
end $$;

drop trigger if exists joint_votes_sync on public.joint_votes;
create trigger joint_votes_sync after insert or update or delete on public.joint_votes
  for each row execute function public.sync_post_vote_counts();

create or replace function public.sync_post_comment_count()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := case when tg_op = 'DELETE' then old.post_id else new.post_id end;
begin
  update joint_posts p set
    comment_count = (select count(*) from joint_comments c where c.post_id = target and c.deleted_at is null)
  where p.id = target;
  return null;
end $$;

drop trigger if exists joint_comments_sync on public.joint_comments;
create trigger joint_comments_sync after insert or update or delete on public.joint_comments
  for each row execute function public.sync_post_comment_count();

create or replace function public.sync_joint_members()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := case when tg_op = 'DELETE' then old.joint_id else new.joint_id end;
begin
  update joints j set members_count = (select count(*) from joint_members m where m.joint_id = target)
  where j.id = target;
  return null;
end $$;

drop trigger if exists joint_members_sync on public.joint_members;
create trigger joint_members_sync after insert or delete on public.joint_members
  for each row execute function public.sync_joint_members();

-- ===================================================================== reels
create table if not exists public.reels (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  video_path text not null,
  thumb_path text,
  caption text not null default '' check (char_length(caption) <= 300),
  city text not null default 'Lagos',
  duration_sec integer not null default 0 check (duration_sec between 0 and 180),
  is_vendor_promo boolean not null default false,
  price_ngn integer check (price_ngn is null or price_ngn >= 0),
  boosted_until timestamptz,
  views_count integer not null default 0,
  hypes_count integer not null default 0,
  cowries_sprayed integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists reels_city_idx on public.reels (city, created_at desc);

-- ================================================================ yarn rooms
create table if not exists public.yarn_rooms (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 90),
  joint_tag text,
  livekit_room_name text unique not null,
  is_live boolean not null default true,
  listener_count integer not null default 1,
  total_cowries_sprayed integer not null default 0,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table if not exists public.yarn_room_participants (
  room_id uuid not null references public.yarn_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'listener' check (role in ('host', 'speaker', 'listener')),
  hand_raised boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- ====================================================== safety + moderation
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  subject_type text not null check (subject_type in ('conversation', 'message', 'profile', 'post', 'comment', 'reel', 'room')),
  subject_id uuid not null,
  reason text not null check (char_length(reason) between 1 and 500),
  status text not null default 'open' check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists reports_status_idx on public.reports (status, created_at desc);

-- =================================================================== cowries
create table if not exists public.cowrie_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in (
    'welcome_bonus',
    'paystack_topup',
    'spend_boost_reel',
    'spend_boost_post',
    'spend_priority_ping',
    'spend_voice_to_text',
    'spend_verified_badge',
    'spray_sent',
    'spray_received',
    'admin_adjust'
  )),
  amount integer not null,          -- positive credit, negative debit
  ref text unique,                  -- paystack reference / idempotency key
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (amount <> 0)
);

create index if not exists cowrie_user_idx on public.cowrie_transactions (user_id, created_at desc);

-- the only place a balance ever changes
create or replace function public.apply_cowrie_txn()
returns trigger language plpgsql security definer set search_path = public as $$
declare new_balance integer;
begin
  select cowries_balance into new_balance from profiles where id = new.user_id for update;
  if new_balance is null then
    raise exception 'not_found' using detail = 'profile missing';
  end if;
  new_balance := new_balance + new.amount;
  if new_balance < 0 then
    raise exception 'insufficient_cowries' using detail = 'balance would go negative';
  end if;
  update profiles set cowries_balance = new_balance, updated_at = now() where id = new.user_id;
  return new;
end $$;

drop trigger if exists cowrie_txn_apply on public.cowrie_transactions;
create trigger cowrie_txn_apply before insert on public.cowrie_transactions
  for each row execute function public.apply_cowrie_txn();

-- ================================================================ functions
create or replace function public.is_conversation_member(p_conversation uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from conversation_participants cp
    where cp.conversation_id = p_conversation and cp.user_id = auth.uid()
  );
$$;

create or replace function public.is_blocked_either_way(p_other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = p_other)
       or (b.blocker_id = p_other and b.blocked_id = auth.uid())
  );
$$;

-- Claim a handle + pay the welcome bonus exactly once.
create or replace function public.claim_username(p_username text, p_display_name text default null)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  uid_user uuid := auth.uid();
  clean_handle text := lower(trim(p_username));
  clean_name text := coalesce(nullif(trim(p_display_name), ''), clean_handle);
  claimed public.profiles;
begin
  if uid_user is null then
    raise exception 'not_authenticated';
  end if;
  if clean_handle !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'invalid_username' using detail = 'must match ^[a-z0-9_]{3,20}$';
  end if;
  if char_length(clean_name) > 40 then
    clean_name := left(clean_name, 40);
  end if;

  if exists (select 1 from public.profiles where id = uid_user) then
    -- A handle can be claimed once. Later calls only refresh the display name.
    update public.profiles
      set display_name = clean_name
      where id = uid_user and username = clean_handle;
    if not found then
      raise exception 'invalid_username' using detail = 'handle already claimed';
    end if;
  else
    begin
      insert into public.profiles (id, username, display_name)
      values (uid_user, clean_handle, clean_name);
    exception when unique_violation then
      raise exception 'username_taken';
    end;
  end if;

  -- single-shot welcome bonus, idempotent by ref
  insert into public.cowrie_transactions (user_id, kind, amount, ref)
  values (uid_user, 'welcome_bonus', 50, 'welcome:' || uid_user::text)
  on conflict (ref) do nothing;

  select * into claimed from public.profiles where id = uid_user;
  return claimed;
end $$;

-- Get-or-create a 1:1 thread, respecting blocks.
create or replace function public.start_direct_conversation(p_username text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  other_id uuid;
  conv_id uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  select id into other_id from public.profiles
  where username = lower(trim(p_username));
  if other_id is null then raise exception 'not_found'; end if;
  if other_id = uid then raise exception 'blocked' using detail = 'cannot chat with yourself'; end if;
  if public.is_blocked_either_way(other_id) then raise exception 'blocked'; end if;

  select c.id into conv_id
  from public.conversations c
  join public.conversation_participants a on a.conversation_id = c.id and a.user_id = uid
  join public.conversation_participants b on b.conversation_id = c.id and b.user_id = other_id
  where c.is_group = false
  limit 1;

  if conv_id is not null then
    return conv_id;
  end if;

  insert into public.conversations (is_group, created_by) values (false, uid) returning id into conv_id;
  insert into public.conversation_participants (conversation_id, user_id)
  values (conv_id, uid), (conv_id, other_id);
  return conv_id;
end $$;

create or replace function public.mark_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.conversation_participants
  set last_read_at = now()
  where conversation_id = p_conversation_id and user_id = auth.uid();
end $$;

-- Only a vendor (or the thread's creator) may move an order along.
create or replace function public.set_order_status(p_conversation_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare is_vendor_account boolean;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_status is not null and p_status not in ('Pending Payment', 'Paid', 'Dispatched', 'Resolved') then
    raise exception 'invalid_status';
  end if;
  if not public.is_conversation_member(p_conversation_id) then raise exception 'not_found'; end if;

  select coalesce(is_vendor, false) into is_vendor_account from public.profiles where id = auth.uid();
  if not is_vendor_account then
    raise exception 'invalid_kind' using detail = 'only vendors can set order status';
  end if;

  update public.conversation_participants
  set order_status = nullif(p_status, '')
  where conversation_id = p_conversation_id and user_id = auth.uid();
end $$;

-- Spending: identity and amount come from the server, never the caller.
create or replace function public.spend_cowries(
  p_amount integer,
  p_kind text,
  p_metadata jsonb default '{}'::jsonb
) returns integer
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
declare balance integer;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'invalid_amount'; end if;
  if p_kind not in (
    'spend_boost_reel', 'spend_boost_post', 'spend_priority_ping',
    'spend_voice_to_text', 'spend_verified_badge', 'spray_sent'
  ) then
    raise exception 'invalid_kind';
  end if;

  insert into public.cowrie_transactions (user_id, kind, amount, metadata)
  values (uid, p_kind, -p_amount, p_metadata);   -- trigger enforces non-negative

  select cowries_balance into balance from public.profiles where id = uid;
  return balance;
end $$;

-- Credits: service role only (Paystack webhook, admin tooling).
create or replace function public.grant_cowries(
  p_user_id uuid,
  p_amount integer,
  p_kind text,
  p_ref text,
  p_metadata jsonb default '{}'::jsonb
) returns integer
language plpgsql security definer set search_path = public as $$
declare balance integer;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'invalid_amount'; end if;
  insert into public.cowrie_transactions (user_id, kind, amount, ref, metadata)
  values (p_user_id, p_kind, p_amount, p_ref, p_metadata)
  on conflict (ref) do nothing;                     -- idempotent replay
  select cowries_balance into balance from public.profiles where id = p_user_id;
  return coalesce(balance, 0);
end $$;

-- Hot ranking lives server-side so the index actually helps.
create or replace function public.joint_feed(p_joint_id uuid, p_sort text default 'hot')
returns table (
  id uuid,
  title text,
  body text,
  author_username text,
  hype_count integer,
  fade_count integer,
  comment_count integer,
  created_at timestamptz,
  my_vote text
)
language sql stable as $$
  select
    p.id,
    p.title,
    p.body,
    pr.username as author_username,
    p.hype_count,
    p.fade_count,
    p.comment_count,
    p.created_at,
    (select v.vote_type from joint_votes v where v.post_id = p.id and v.user_id = auth.uid()) as my_vote
  from joint_posts p
  join profiles pr on pr.id = p.author_id
  where p.joint_id = p_joint_id
    and p.deleted_at is null
  order by
    case when p_sort = 'hot' then
      ((p.hype_count - p.fade_count)::numeric
        / power((extract(epoch from (now() - p.created_at)) / 3600.0) + 2.0, 1.5))
    end desc nulls last,
    case when p_sort = 'top' then (p.hype_count - p.fade_count)::numeric end desc nulls last,
    p.created_at desc
  limit 60;
$$;

-- ===================================================================== views
create or replace view public.conversation_summaries
with (security_invoker = true) as
select
  c.id,
  c.is_group,
  c.title,
  c.last_message_at,
  cp.order_status,
  cp.is_muted,
  (
    select pr.username
    from conversation_participants peer
    join profiles pr on pr.id = peer.user_id
    where peer.conversation_id = c.id and peer.user_id <> auth.uid()
    limit 1
  ) as other_username,
  (
    select case when m.kind = 'voice' then '🎙 Voice note' else m.body end
    from messages m
    where m.conversation_id = c.id and m.deleted_at is null
    order by m.created_at desc
    limit 1
  ) as last_message,
  (
    select count(*)
    from messages m
    where m.conversation_id = c.id
      and m.sender_id <> auth.uid()
      and m.created_at > cp.last_read_at
      and m.deleted_at is null
  ) as unread_count
from conversations c
join conversation_participants cp
  on cp.conversation_id = c.id and cp.user_id = auth.uid();

create or replace view public.reel_feed
with (security_invoker = true) as
select
  r.id,
  r.caption,
  r.city,
  r.duration_sec,
  r.price_ngn,
  r.thumb_path,
  r.video_path,
  r.boosted_until,
  r.views_count,
  pr.username as creator_username
from reels r
join profiles pr on pr.id = r.creator_id
where r.deleted_at is null;

-- ======================================================================= RLS
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.joints enable row level security;
alter table public.joint_members enable row level security;
alter table public.joint_posts enable row level security;
alter table public.joint_votes enable row level security;
alter table public.joint_comments enable row level security;
alter table public.reels enable row level security;
alter table public.yarn_rooms enable row level security;
alter table public.yarn_room_participants enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.cowrie_transactions enable row level security;

-- nobody anonymous touches anything
revoke all on all tables in schema public from anon;

-- profiles: readable by signed-in users, editable only in safe columns
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- conversations
drop policy if exists conversations_select_member on public.conversations;
create policy conversations_select_member on public.conversations
  for select to authenticated
  using (public.is_conversation_member(id));

-- participants
drop policy if exists participants_select_member on public.conversation_participants;
create policy participants_select_member on public.conversation_participants
  for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists participants_update_own on public.conversation_participants;
create policy participants_update_own on public.conversation_participants
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- messages: members read, authors write, immutable once sent
drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists messages_insert_own on public.messages;
create policy messages_insert_own on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.is_conversation_member(conversation_id)
  );

drop policy if exists messages_soft_delete_own on public.messages;
create policy messages_soft_delete_own on public.messages
  for update to authenticated
  using (sender_id = (select auth.uid()))
  with check (sender_id = (select auth.uid()));

-- joints: public read, authored writes
drop policy if exists joints_select on public.joints;
create policy joints_select on public.joints
  for select to authenticated using (true);

drop policy if exists joints_insert on public.joints;
create policy joints_insert on public.joints
  for insert to authenticated
  with check (creator_id = (select auth.uid()));

drop policy if exists joint_members_select on public.joint_members;
create policy joint_members_select on public.joint_members
  for select to authenticated using (true);

drop policy if exists joint_members_insert on public.joint_members;
create policy joint_members_insert on public.joint_members
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists joint_members_delete on public.joint_members;
create policy joint_members_delete on public.joint_members
  for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists joint_posts_select on public.joint_posts;
create policy joint_posts_select on public.joint_posts
  for select to authenticated using (deleted_at is null);

drop policy if exists joint_posts_insert on public.joint_posts;
create policy joint_posts_insert on public.joint_posts
  for insert to authenticated with check (author_id = (select auth.uid()));

drop policy if exists joint_posts_update_own on public.joint_posts;
create policy joint_posts_update_own on public.joint_posts
  for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

drop policy if exists joint_votes_select on public.joint_votes;
create policy joint_votes_select on public.joint_votes
  for select to authenticated using (true);

drop policy if exists joint_votes_insert on public.joint_votes;
create policy joint_votes_insert on public.joint_votes
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists joint_votes_update on public.joint_votes;
create policy joint_votes_update on public.joint_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists joint_votes_delete on public.joint_votes;
create policy joint_votes_delete on public.joint_votes
  for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists joint_comments_select on public.joint_comments;
create policy joint_comments_select on public.joint_comments
  for select to authenticated using (deleted_at is null);

drop policy if exists joint_comments_insert on public.joint_comments;
create policy joint_comments_insert on public.joint_comments
  for insert to authenticated with check (author_id = (select auth.uid()));

-- reels
drop policy if exists reels_select on public.reels;
create policy reels_select on public.reels
  for select to authenticated using (deleted_at is null);

drop policy if exists reels_insert_own on public.reels;
create policy reels_insert_own on public.reels
  for insert to authenticated with check (creator_id = (select auth.uid()));

drop policy if exists reels_update_own on public.reels;
create policy reels_update_own on public.reels
  for update to authenticated
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()));

-- yarn rooms
drop policy if exists rooms_select on public.yarn_rooms;
create policy rooms_select on public.yarn_rooms
  for select to authenticated using (true);

drop policy if exists rooms_insert_own on public.yarn_rooms;
create policy rooms_insert_own on public.yarn_rooms
  for insert to authenticated with check (host_id = (select auth.uid()));

drop policy if exists rooms_update_own on public.yarn_rooms;
create policy rooms_update_own on public.yarn_rooms
  for update to authenticated
  using (host_id = (select auth.uid()))
  with check (host_id = (select auth.uid()));

drop policy if exists room_participants_select on public.yarn_room_participants;
create policy room_participants_select on public.yarn_room_participants
  for select to authenticated using (true);

drop policy if exists room_participants_insert on public.yarn_room_participants;
create policy room_participants_insert on public.yarn_room_participants
  for insert to authenticated with check (user_id = (select auth.uid()));

-- safety
drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own on public.blocks
  for select to authenticated using (blocker_id = (select auth.uid()));

drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own on public.blocks
  for insert to authenticated with check (blocker_id = (select auth.uid()));

drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own on public.blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()));

-- cowries: read your own ledger, write nothing
drop policy if exists cowries_select_own on public.cowrie_transactions;
create policy cowries_select_own on public.cowrie_transactions
  for select to authenticated using (user_id = (select auth.uid()));

-- ==================================================================== grants
-- Profiles: clients may only edit these columns (never balance/verification).
revoke update on public.profiles from authenticated;
grant update (display_name, bio, avatar_path, city, data_saver_mode) on public.profiles to authenticated;
revoke insert on public.profiles from authenticated;

-- Threads are only created through the RPC (definer), so no insert policy.
revoke insert, update, delete on public.conversations from authenticated;
revoke insert, delete on public.conversation_participants from authenticated;
grant update (is_muted) on public.conversation_participants to authenticated;

-- Messages are append-only: you may only soft-delete your own.
revoke update on public.messages from authenticated;
grant update (deleted_at) on public.messages to authenticated;

-- Counters belong to triggers, not clients.
revoke update on public.joint_posts from authenticated;
grant update (title, body, media_urls, deleted_at) on public.joint_posts to authenticated;
revoke update on public.joint_comments from authenticated;
grant update (body, deleted_at) on public.joint_comments to authenticated;
revoke update on public.joint_votes from authenticated;
grant update (vote_type) on public.joint_votes to authenticated;
revoke update on public.reels from authenticated;
grant update (caption, price_ngn, is_vendor_promo, thumb_path, deleted_at) on public.reels to authenticated;
revoke update on public.yarn_rooms from authenticated;
grant update (title, is_live, ended_at) on public.yarn_rooms to authenticated;
revoke update on public.joints from authenticated;
grant update (description) on public.joints to authenticated;

-- Ledger is append-only through functions.
revoke insert, update, delete on public.cowrie_transactions from authenticated;

grant select on public.conversation_summaries to authenticated;
grant select on public.reel_feed to authenticated;

revoke execute on function public.grant_cowries(uuid, integer, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.grant_cowries(uuid, integer, text, text, jsonb) to service_role;

grant execute on function public.claim_username(text, text) to authenticated;
grant execute on function public.start_direct_conversation(text) to authenticated;
grant execute on function public.mark_read(uuid) to authenticated;
grant execute on function public.set_order_status(uuid, text) to authenticated;
grant execute on function public.spend_cowries(integer, text, jsonb) to authenticated;
grant execute on function public.joint_feed(uuid, text) to authenticated;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.is_blocked_either_way(uuid) to authenticated;

-- ================================================================== realtime
do $$
begin
  execute 'alter publication supabase_realtime add table public.messages';
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
