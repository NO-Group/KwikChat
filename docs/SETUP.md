# Setup — from zero to a running build

You need: a Supabase project, a GitHub repo (this one), and a Cloudflare account
for `kwikchat.no-group.org`.

---

## 1. Backend (Supabase) — 5 minutes

1. Create a project at [supabase.com](https://supabase.com) (pick the region
   closest to Nigeria — `eu-central-1` or `eu-west-1` are the usual choices).
2. **SQL Editor → New query**, paste the whole of
   `supabase/migrations/0001_init.sql`, run it. Then run
   `supabase/migrations/0002_storage.sql`, then `supabase/seed.sql`.
3. **Authentication → Providers → Email**: keep "Email OTP" enabled. Turn off
   "Confirm email" for now if you want instant sign-in while testing.
4. **Authentication → URL configuration**: add your site URL
   (`https://kwikchat.no-group.org`) and `http://localhost:8080` as a redirect.
5. Copy from **Project Settings → API**:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`

Never put the `service_role` key in the app, and never commit it.

### Verify the security model before writing any UI

Run these in the SQL editor as a sanity check — every one should come back
non-zero or `true`:

```sql
select count(*) from pg_policies where schemaname = 'public';   -- expect 36
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r';  -- all true
```

Then, from the app with two different accounts: user B must **not** see user A's
messages. That single test catches the class of bug the original spec shipped.

---

## 2. Run it locally

```bash
flutter pub get

# web (what the Cloudflare build produces)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# android
flutter run -d <device> --dart-define=...

# windows / linux / macos (desktop targets must be enabled once)
flutter config --enable-windows-desktop --enable-linux-desktop --enable-macos-desktop
flutter run -d windows --dart-define=...
```

Without the `--dart-define` flags the app shows a "Backend not configured" card
on purpose, instead of a white screen.

---

## 3. GitHub Actions → your Releases page

Add these **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Required | Purpose |
|---|---|---|
| `SUPABASE_URL` | yes | baked into every build |
| `SUPABASE_ANON_KEY` | yes | baked into every build |
| `CLOUDFLARE_API_TOKEN` | optional | auto-deploy web to Pages |
| `CLOUDFLARE_ACCOUNT_ID` | optional | same |

Then:

```bash
git tag v0.1.0
git push origin v0.1.0
```

`Build & Release` compiles **arm64 + arm32 Android APKs, a Windows zip and a web
tar.gz**, and attaches them to the GitHub Release for that tag. Tags with a
hyphen (`v0.1.0-preview.1`) are published as pre-releases.

App icons are generated from `assets/kwikchat_logo.png` during the build
(`icons/android.yaml`, `icons/windows.yaml`, `icons/ios.yaml`) using
`flutter_launcher_icons`, because the platform folders themselves are generated.
Icons are configured per platform on purpose: a single global config makes the
tool look for folders a given job never created, which fails the build.

CI tracks the **current Flutter stable channel** rather than a pinned SDK, and
generates the platform runners with `flutter create` on every run — so the
scaffolding can never drift from the toolchain. (An early pinned SDK caused
exactly that: Flutter 3.35 still emitted a Visual Studio 2019 CMake project,
which current Windows runners no longer ship.)

Linux desktop is intentionally not in the matrix for v0.1: `record_linux`
0.7.2 cannot implement `RecordPlatform.startStream` from
`record_platform_interface` 1.6.0, so that target does not compile. Re-enable
the matrix entry once the plugin releases a compatible version.

### Why the Android APK is debug-signed

`flutter create` signs release builds with the debug keystore. That is fine for
sideloading to testers. Before you put it on Play, create a real keystore and
add `android/key.properties` (already in `.gitignore`) — see
[Flutter's signing guide](https://docs.flutter.dev/deployment/android#signing-the-app).

### iOS

iOS needs macOS + an Apple Developer account ($99/yr) and cannot be built on
Linux runners. Two options: a macOS runner in the matrix (uncomment it, ~10x
minutes, needs certificates in secrets), or `flutter build ipa` on your own Mac.
The web/PWA build is installable on iPhone today via Safari → Share → **Add to
Home Screen**, which is the honest v0.1 answer for iOS.

---

## 4. Cloudflare Pages (`kwikchat.no-group.org`)

The `deploy-web` job publishes with `wrangler pages deploy` when both
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` secrets exist, and prints a
skip notice (exit 0) when they don't — so an unconfigured Cloudflare never
breaks a release.

Either let the workflow deploy (set the two Cloudflare secrets), or point Pages
at the repo yourself:

- **Framework preset:** None
- **Build command:** `flutter build web --release --base-href=/ --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY` (or let the `deploy-web` job do it)
- **Build output directory:** `build/web`
- **Environment variables:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` (plus Flutter
  on the build image, or use the workflow instead)

The included `web/index.html` already has the manifest, theme colour, iOS
standalone meta tags and a branded splash that clears on `flutter-first-frame`.

---

## 5. Paystack (only when you start selling Cowries)

```bash
supabase functions deploy paystack-webhook --no-verify-jwt
supabase secrets set PAYSTACK_SECRET_KEY=sk_live_xxx
```

Point the Paystack dashboard webhook at
`https://<project>.supabase.co/functions/v1/paystack-webhook`.

**Checkout must put `metadata.user_id` = the buyer's Supabase uid.** The webhook
refuses to credit on an email match — that is an account-takeover path.

Read `docs/CORRECTIONS.md` §9 before wiring a purchase button in the mobile app:
store billing differs from the web flow.

---

## 6. First-run checklist

- [ ] Sign in with email → code arrives → claim `@handle` → you land in Chats
- [ ] Wallet shows **50 Cowries** (welcome bonus, granted once)
- [ ] Second account: message the first account by `@username`
- [ ] Voice note records, uploads, plays back on both sides
- [ ] Switch to airplane mode → threads still open from cache, banner appears
- [ ] Post in `+TechNaija`, hype a post, watch the count recompute
- [ ] Attempt `select * from messages` as a non-participant → zero rows
- [ ] `flutter analyze` clean, `flutter test` green
