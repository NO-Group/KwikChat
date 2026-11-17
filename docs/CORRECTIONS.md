# Corrections to the v1.0 blueprint

Every item below is a change between `docs/PRD.md` (the original spec) and what
is actually implemented in this repo. Nothing here is cosmetic — each one was a
hole that would have bitten in production.

## 1. Row Level Security now exists

**Was:** the PRD said "initialise all tables, indexes, Row-Level Security
policies", then shipped 14 `CREATE TABLE` statements and **zero** `CREATE
POLICY`. On Supabase that means any signed-in user could read every message,
every profile and the whole Cowrie ledger with a single `select()`.

**Now:** `0001_init.sql` enables RLS on all 15 tables, defines 36 policies, and
revokes `anon` access wholesale. Every policy is written against
`(select auth.uid())` so Postgres can cache the auth lookup once per statement
instead of once per row.

**Verified shape:** `messages` is readable only by conversation participants
via `is_conversation_member()` (a `SECURITY DEFINER` helper, which also avoids
the classic recursive-RLS deadlock when a policy on `participants` needs to read
`participants`).

## 2. Cowries are a ledger, not a number

**Was:** `profiles.cowries_balance INTEGER` plus a `cowrie_transactions` table
with nothing linking them. Two sources of truth, guaranteed drift, and a client
that could `update profiles set cowries_balance = 999999`.

**Now:** balances change **only** through the ledger. `apply_cowrie_txn()`
(a `BEFORE INSERT` trigger) locks the profile row, applies `amount`, and raises
`insufficient_cowries` if it would go negative — one atomic transaction, no race
condition. Clients have `revoke update (cowries_balance)`; the column-level
grant list is explicit (`display_name, bio, avatar_path, city,
data_saver_mode`). There is a test-able invariant: `cowries_balance` always
equals `sum(amount)` for that user.

## 3. `spend_cowries()` no longer trusts the caller

**Was:** `spend_cowries(p_user_id UUID, ...)` — a `SECURITY DEFINER` function
that let any authenticated user pass *any* user id, any amount, and any
`tx_type` string. That is an account-draining primitive.

**Now:** `spend_cowries(p_amount, p_kind, p_metadata)` derives the user from
`auth.uid()`, rejects non-positive amounts, and whitelists spend kinds
server-side. `grant_cowries()` (credits) is revoked from `authenticated` and
`anon` — only `service_role` (the Paystack webhook) may call it.

## 4. Messages are durable

**Was:** `ephemeral_messages`, purged from Postgres and R2 within 24h of
delivery, 7-day maximum TTL. Consequences: replace your phone and your chat
history is gone; no multi-device; no web later; silent loss for anyone offline
past the TTL; and the vendor order thread — the commerce feature — deletes
itself.

**Now:** `messages` is a normal durable table. Retention becomes a *policy*
(soft delete via `deleted_at`), not an architectural assumption. Local cache
keeps the last ~80 messages per thread, so the "zero-bloat storage" promise is
kept on the device side instead of being paid for with data loss.

## 5. No marketing of encryption that isn't there

**Was:** a column named `encrypted_content` with no encryption, no key
management, no E2EE design — while the brand promises privacy.

**Now:** the column is honestly named `body`, and the privacy claim we make is
the one we actually deliver: identity-level privacy (`@username` first, phone
number and email never exposed) plus RLS-scoped access. E2EE is a v0.3 project
with a written threat model, not a column rename. Under the NDPA 2023, claiming
E2EE you don't have is a liability, not marketing.

## 6. Media is private, and paths are opaque

Voice notes upload to a **private** Supabase Storage bucket whose RLS only
permits writes into `media/<your-uid>/…`; playback uses short-lived signed URLs.
Paths are UUIDs, so they cannot be enumerated.

Known limitation, documented rather than hidden: read access is "any signed-in
user with the exact path" rather than a per-participant check, because a
participant predicate on `storage.objects` needs a join per object. v0.2 moves
media to Cloudflare R2 behind a presigned-URL edge function, at which point the
participant check moves into the signer and this limitation disappears.

## 7. Counters are computed, not incremented

**Was:** `hype_count`, `fade_count`, `comment_count`, `members_count` with
defaults and no triggers — they drift the moment anyone un-votes, and clients
could set them.

**Now:** `AFTER INSERT/UPDATE/DELETE` triggers on `joint_votes`,
`joint_comments` and `joint_members` recompute counts from source rows
(`case when tg_op = 'DELETE' …` so deletes are handled too). `revoke update`
on those tables means only `title/body/deleted_at` are client-writable.

## 8. Hot ranking is server-side

**Was:** an index on `(boosted_until DESC NULLS LAST, created_at DESC)`, which
cannot serve a time-decay formula.

**Now:** `joint_feed(p_joint_id, p_sort)` ranks in SQL (Hacker-News-style decay:
`(hype - fade) / (age_hours + 2)^1.5`), so the query planner can do the work and
the client can't re-sort into a different product. `my_vote` comes back with
each post, so no second round trip.

## 9. Store billing is designed for, not discovered at review

**Was:** a Paystack checkout sheet selling Cowries inside the app.

Apple Guideline 3.1.1 requires In-App Purchase for any in-app currency, and
Google Play requires Play Billing for digital goods. A Paystack button for
Cowries gets the build rejected; linking out to a web checkout without an
entitlement is the same violation. That is not a policy detail — it changes the
wallet.

**Now:** the ledger, the RPCs and the webhook are store-agnostic and already
built. The purchase sheet is deliberately not wired. The path is: Play Billing /
StoreKit on mobile (accounting for the 15–30% cut) and Paystack on web, both
crediting the same `grant_cowries(ref)` idempotently. Small bundles are still
viable because Paystack waives the ₦100 fee under ₦2,500 — but the store cut,
not Paystack, is what sets mobile pricing.

## 10. Data-Saver needs two renditions on the server

**Was:** a client toggle claiming 720p ↔ 480p. A toggle cannot downscale a
720p MP4 that the server only has in one quality.

**Now:** documented as a media-pipeline requirement: encode an HLS ladder
(480p ≈ 400–600 kbps, 720p) and have the toggle select a variant. Also,
`video_compress` on a 2 GB Tecno transcoding 1080p is a thermal-throttled
disaster: capture at low bitrate natively and transcode server-side (Cloudflare
Stream / Media Transform) instead of asking the cheapest device to do the
hardest work.

## 11. Local store chosen for four platforms, not one

**Was:** "Isar or Drift". Isar is a community fork of a stalled project, and
Drift-on-web needs SQLite WASM plus worker files.

**Now:** `shared_preferences` behind a `LocalCache` interface — works on
IndexedDB, Android, iOS, Windows, Linux with zero codegen and zero native build
steps. The interface is the point: swap in Drift when message volume justifies
SQL, and no screen changes.

## 12. Moderation exists from day one

**Was:** nothing. No report, no block, no tooling — for an app with live audio,
anonymous handles and threaded forums. Apple's Guideline 1.2 rejects UGC apps
without reporting/blocking, and more importantly this market has real scam and
abuse patterns.

**Now:** `blocks` and `reports` tables with RLS (report your own, read your
own), a block check inside `start_direct_conversation()` so a blocked person
cannot re-open a thread, and an in-thread Report / Block-and-report flow.

## 13. Smaller fixes

- `order_status IN (NULL, …)` never matches anything — `NULL` comparisons are
  `NULL`. Replaced with `is null or order_status in (…)`.
- `auth.uid()` unqualified on 15 policies → `(select auth.uid())` for
  per-statement caching.
- Email OTP before phone OTP: SMS is a real per-signup cost and an
  account-farming subsidy when paired with free welcome Cowries.
- `username` uniqueness is enforced by a `unique` constraint **and** validated
  by regex in `claim_username()`, so a handle can be claimed exactly once and
  never silently reassigned.
- The Paystack webhook verifies HMAC-SHA512 against the **raw** body (parsing
  then re-serialising silently breaks the signature) and credits by
  `paystack:<reference>` for idempotency.
