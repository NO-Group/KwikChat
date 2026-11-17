# KwikChat

KwikChat — Master Product Requirements & Technical Architecture Specification (PRD & Engineering Blueprint)

Document Version: 1.0 (Production Build Blueprint)
Target Platform: Android & iOS (Flutter Cross-Platform)
Primary Market: Nigeria (Built natively for Nigerian network, device, and cultural realities, engineered for global scalability)
Target Engineering Agent: Arena.ai Full-Stack / Mobile Engineering Agent

1. Executive Summary & Brand Identity


1.1 Product Overview

KwikChat is an all-in-one, lightweight, high-speed social messaging and community super-app born in Nigeria and built for the world. It unifies four high-engagement social pillars into a single, ultra-low-data mobile application:
1. Ephemeral, Offline-First Instant Messaging (Chats): Fast 1-on-1 and group messaging with @username privacy (eliminating forced phone number exposure) and zero-bloat local device storage.
2. Live Audio Hangouts (Yarn Rooms): Real-time, multi-speaker audio rooms for street banter, football discussions, debates, and language/community sessions.
3. Short-Form Vertical Video (Reels): High-speed, client-compressed vertical videos with an explicit Data-Saver Mode and built-in vendor-to-chat commerce hooks.
4. Topic-Based Community Boards (+ Joints): Threaded community forums (formatted with a + prefix, e.g., +TechNaija, +KadunaHustle) featuring a custom Hype / Fade voting mechanism.

1.2 Brand Identity & Core Copy

• Official App Name: KwikChat (Short verb usage: "KwikChat me", "Send it on KwikChat")
• Official Catchphrase / Tagline: "No long talk. Just KwikChat."
• In-App Digital Currency: Cowries (Closed-loop digital credits used for boosting posts, spraying creators/speakers, unlocking AI voice-to-text, and purchasing stickers/badges).
• Logo & Visual Mark: A rounded square dark Graphene container (#0f1110) housing a thick-outlined electric lime (#b8f226) circular speech bubble with its tail pointing to the bottom-left, speed-trail breaks along the top-right arc, and the bold lowercase wordmark kwik centered inside with a four-point electric spark accenting the dot of the "i".

1.3 Core Value Propositions (Market Differentiators)

• Radical Data & Storage Efficiency: Every media asset (videos, images, voice notes) is compressed on the client device prior to upload. Chat histories live primarily on the user's local device database (Isar / Drift), preventing cloud storage bloat and keeping the app fast on budget Android phones (32GB/64GB storage) and unstable 2G/3G/4G connections.
• Privacy-First Identity (@username Architecture): Users register and connect via unique @handles without exposing their personal mobile phone numbers to strangers, group members, or marketplace vendors.
• Commerce-Ready Social Funnel: Vendors can showcase products via Reels, dedicated Market feeds, and + Joint threads with a single-tap "Message Vendor" CTA that opens an instant KwikChat thread.
• Human-Centric Trust & Verification: Vendors and power users can verify accounts using Nigerian identity standards (NIN/CAC) to earn trust badges, preventing impersonation and fake review screenshots.

2. Complete Design System & UI/UX Tokens

The KwikChat interface uses the Tungsten Graphene color system—a high-contrast, developer-grade dark aesthetic paired with an accessible, WCAG AA-compliant daylight theme.

2.1 Semantic Color Tokens


Semantic Token	Dark Theme (Default)	Light Theme (Daylight)	UI Usage & Component Mapping
--bg	#0f1110	#f6f8f7	Main application canvas, scaffold background
--surface	#171a18	#ffffff	Cards, bottom navigation bar, message bubbles (incoming), modals
--surface-2	#1f2421	#eef1ef	Input fields, search bars, nested containers, pill tags
--border	#2c332f	#d5ddd8	1px hairline dividers, card outlines, input borders
--accent	#b8f226	#658c08	Primary CTAs, active navigation icons, outgoing chat bubbles, Hype active state
--accent-dim	rgba(184, 242, 38, 0.12)	rgba(101, 140, 8, 0.10)	Active filter pills, subtle badges, selected tabs
--accent-on	#0f1110	#ffffff	Text and icons rendered directly on top of --accent surfaces
--text	#e8ece9	#121513	Primary body copy, usernames, post titles, message text
--muted	#98a39c	#5c6861	Timestamps, secondary metadata, read receipts, inactive icons
--code-bg	#0a0c0b	#f0f3f1	Monospace handles, transaction IDs, code/link previews
--danger	#ff5c5c	#d9383a	Fade active state, error alerts, block/report actions, recording indicator
--info	#4cc9f0	#0284c7	Verified badges, system announcements, link highlights


2.2 Typography & Layout Guidelines

• Primary Font Family: Inter or Plus Jakarta Sans (clean, geometric sans-serif with high legibility on small screens).
• Monospace Font Family: JetBrains Mono (used for @usernames, +Joint tags, Cowries wallet balances, and transaction references).
• Corner Radii:
	• Cards & Containers: 16px
	• Buttons & Inputs: 12px
	• Chat Bubbles: 18px (with a sharp 4px corner on the sender/receiver tail side)
	• Pills & Badges: 999px (Full capsule)
• Navigation Architecture (4-Tab Bottom Navigation Bar):
	1. Chats (Icon: Speech bubble with spark) — Includes a horizontal scrollable strip of active Yarn Rooms pinned at the very top of the screen.
	2. Reels (Icon: Vertical play frame) — Full-bleed vertical video player with top toggle (For You | Naija / Nearby) and a persistent Data-Saver pill.
	3. + Joints (Icon: Bold + inside square) — Reddit-inspired community feed sorted by Hot, New, and Top, powered by Hype / Fade voting.
	4. Market & Wallet (Icon: Cowrie shell / Storefront) — Searchable vendor catalog feed, Cowries balance card, Paystack top-up flow, and user profile/settings.

3. Detailed Functional Specifications (All 5 Core Modules)


3.1 Module 1: Ephemeral, Offline-First Messaging (Chats)

• Identity & Discovery:
	• Users sign up via Email or Phone OTP, then immediately claim a unique @username (e.g., @amina_kd).
	• Phone numbers are hashed/private by default; users can find friends via @username search, QR code scan, or optional contact-book matching (without revealing their number to non-contacts).
• Message Types & Compression:
	• Text Messages: Instant delivery over WebSockets (Supabase Realtime) with delivery states (Sending -> Sent -> Delivered -> Read).
	• Voice Notes (High Priority Feature): Tap-and-hold or lock-to-record audio encoded in lightweight AAC/Opus (24kbps–32kbps), keeping a 1-minute voice note under 250 KB. Includes waveform visualization and 1x / 1.5x / 2x playback speed.
	• Images & Video Clips: Compressed client-side (max 1080p, 70% JPEG/WebP quality) before uploading to a temporary bucket on Cloudflare R2.
	• Priority Ping (Cowries Feature): Users can spend 20 Cowries to send a Priority Ping, which triggers a high-priority push notification and audible chime even if the recipient has muted the conversation.
• Ephemeral Cloud Sync & Local Persistence:
	• Messages are written to the sender's local database (Isar/Drift) immediately for zero-latency UI rendering.
	• The payload transmits via Supabase Realtime. Once the recipient's device acknowledges receipt (ack), the message is saved to the recipient's local Isar/Drift database.
	• Auto-Purge Policy: Delivered messages and temporary R2 media files are marked delivered = true and automatically purged from Supabase and Cloudflare R2 via a scheduled cron job every 24 hours (with a strict 7-day maximum TTL for offline recipients).
• Vendor Business Tools Inside Chat:
	• Business accounts can tag any 1-on-1 chat thread with order status labels: Pending Payment, Paid, Dispatched, or Resolved, preventing customer orders from getting lost in busy inboxes.

3.2 Module 2: Live Audio Hangouts (Yarn Rooms)

• Concept: Drop-in, real-time audio rooms inspired by HelloTalk Voice Rooms, displayed as live pills at the top of the Chats tab and discoverable via a dedicated modal.
• Room Roles:
	• Host: Creates the room, sets the title, links an optional +Joint topic (e.g., +PremierLeague), manages speaker permissions, and can mute or remove disruptive users.
	• Speakers (Up to 8–12 active mics): Users invited to the stage by the Host to speak live.
	• Listeners (Unlimited): Users listening to the conversation who can react with emojis, send live text comments in the room chat drawer, or tap "Raise Hand" to request speaker access.
• Low-Data Audio Streaming:
	• Powered by LiveKit (or Agora) WebRTC audio-only rooms configured with Opus voice codec (16kbps–24kbps mono) and automatic echo cancellation, consuming less than 10 MB per hour of listening.
• Monetization in Yarn Rooms (Cowries Spraying):
	• Listeners can tap the Spray Cowries button to gift animated Cowrie bundles (10, 50, 100, or 500 Cowries) to the Host or active Speakers. Triggering a spray displays a sleek lime-accented animation banner across the room stage.

3.3 Module 3: Short-Form Vertical Video (Reels)

• Playback & Feed Architecture:
	• Full-screen PageView.builder vertical video feed with pre-fetching of the next 2 videos in the queue.
	• Dual Feed Switcher: For You (algorithmic global + trending feed) and Naija / Local (geo-filtered by city/region such as Lagos, Abuja, Kaduna, Port Harcourt, Kano).
• Built-In Data-Saver Mode (Crucial Differentiator):
	• A prominent toggle at the top of the Reels player allows users to switch between Standard HD (720p) and Data-Saver (480p / Low Bitrate).
	• When Data-Saver is active, videos are streamed at ~400–600 kbps (approx. 1.5 MB per 30-second Reel), and pre-fetching is restricted to 1 video ahead.
• Client-Side Video Compression:
	• Before uploading a Reel, the Flutter app runs video_compress locally to transcode the raw camera file into an H.264 MP4 (720p, 30fps, 1.2 Mbps target bitrate), shrinking a 60 MB phone recording down to ~3–5 MB before upload.
• Commerce & Creator Actions:
	• Vendor CTA Button: Creators with a Vendor Profile can attach an action button directly on their Reel (e.g., Message Vendor or View Price: ₦15,000) that deep-links straight into a 1-on-1 KwikChat conversation with the Reel thumbnail quoted.
	• Spray Creator & Boost Reel: Viewers can spray Cowries on any Reel; creators/vendors can spend 100 Cowries to boost a Reel into the top local feed for 24 hours.

3.4 Module 4: Topic Community Boards (+ Joints)

• Naming & Structure:
	• Communities are called Joints and are prefixed with a plus sign (+), such as +TechNaija, +JapaGist, +KadunaMarket, +NaijaMusic, and +CampusLife.
	• Anyone can create a public or moderated +Joint and define community rules.
• Post Types:
	• Text discussions, image galleries (up to 4 compressed images), link shares, and native 2-to-4-option Polls.
• Custom Voting Mechanism (Hype / Fade):
	• Instead of standard arrows, every post and nested comment features Hype (upvote/co-sign, rendered in electric lime #b8f226 when active) and Fade (downvote/bury spam, rendered in #ff5c5c when active).
	• Net score (hype_count - fade_count) combined with time-decay determines ranking in the Hot feed.
• Threaded Comments & Cowrie Awards:
	• Supports infinite/collapsible nested replies.
	• Users can spend 50 Cowries to give a post a Gold Cowrie Award, highlighting the card with a subtle lime border (--accent) and pinning it higher in the +Joint feed.

3.5 Module 5: Cowries Economy, Paystack Integration & AI Perks

• Closed-Loop Compliance Model:
	• Cowries are strictly a non-cashable, closed-loop in-app digital credit. Users purchase Cowries with Naira (via Paystack) and spend them on digital perks, boosts, and gifts inside KwikChat. Users cannot withdraw or convert Cowries back into Naira, keeping KwikChat 100% compliant with Central Bank of Nigeria (CBN) regulations and Paystack's Terms of Service without needing a banking license.
• Cowrie Purchase Bundles (Paystack Checkout):
	• Starter Pouch: 100 Cowries — ₦500
	• Hustler Bag: 550 Cowries (500 + 50 Bonus) — ₦2,500
	• Oga Chest: 1,200 Cowries (1,000 + 200 Bonus) — ₦5,000
	• Chief Vault: 3,000 Cowries (2,500 + 500 Bonus) — ₦10,000
• Ways Users Spend Cowries:
	1. Boost Market Status / Reel (100 Cowries): Pins a vendor's listing or Reel to the top of the local Market/Reels feed for 24 hours.
	2. Verified Vendor Badge (500 Cowries / month): Activates a blue/lime verification badge after NIN/CAC review.
	3. Local Language & Pidgin AI Voice-to-Text (10 Cowries / transcription or 100 Cowries / 15-pack): Transcribes incoming voice notes in Nigerian Pidgin, Yoruba, Hausa, Igbo, or English into text—ideal when users are in noisy buses/markets or want to read a long voice note without playing audio.
	4. Priority Ping (20 Cowries): Bypasses mute settings on an urgent 1-on-1 chat message.
	5. Yarn Room & Reel Spraying (10–500 Cowries): Animated digital gifts sent to live speakers and video creators.
	6. Custom Nigerian Sticker Packs (50–150 Cowries): Unlockable local reaction packs.

4. Technical Architecture ("Split-Storage" Stack)

To ensure sub-second load times in Nigeria while maintaining near-zero infrastructure costs during early scale, KwikChat implements a 4-Tier Split-Storage Architecture:
┌─────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENT (iOS / Android)                   │
│  ┌──────────────────────┐  ┌───────────────────┐  ┌──────────────────┐  │
│  │ Local DB (Drift/Isar)│  │ Media Compressor  │  │ Video/Img Cache  │  │
│  │ - Offline Chat Hist. │  │ - video_compress  │  │ - cached_net_img │  │
│  │ - Drafts & Contacts  │  │ - flutter_img_cmp │  │ - file_cache_mgr │  │
│  └──────────┬───────────┘  └─────────┬─────────┘  └────────┬─────────┘  │
└─────────────┼────────────────────────┼─────────────────────┼────────────┘
              │ WebSockets / REST      │ Presigned PUT       │ HTTPS GET (Zero Egress)
              ▼                        ▼                     ▼
┌──────────────────────────┐  ┌───────────────────────────────────────────┐
│   SUPABASE (Backend)     │  │         CLOUDFLARE R2 (Object Storage)    │
│ - PostgreSQL (Metadata,  │  │ - /reels/ (Compressed MP4s + Thumbnails)  │
│   Profiles, +Joints,     │  │ - /avatars/ (WebP Profile Photos)         │
│   Cowries Ledger)        │  │ - /ephemeral_chat/ (Auto-purged in 7d)    │
│ - Realtime (Chat & Live) │  │ - Lagos Edge CDN Caching ($0 Egress Fee)  │
│ - Edge Functions (Deno)  │  └───────────────────────────────────────────┘
└─────────────┬────────────┘
              │
              ├──────────────────────┐
              ▼                      ▼
┌──────────────────────────┐  ┌───────────────────────────────────────────┐
│    PAYSTACK API          │  │    LIVEKIT / AGORA + AI TRANSCRIPTION     │
│ - Checkout & Webhooks    │  │ - Low-bitrate WebRTC Yarn Rooms           │
│ - Cowries Top-up Verify  │  │ - Whisper API (Pidgin/Yoruba/Hausa/Igbo)  │
└──────────────────────────┘  └───────────────────────────────────────────┘

4.1 Recommended Flutter Package Stack (pubspec.yaml)

• State Management & Routing: flutter_riverpod + go_router
• Backend & Realtime: supabase_flutter
• Local Offline Storage: drift (with sqlite3_flutter_libs) or isar_community for fast, encrypted local chat storage
• Media Compression: video_compress (for Reels/video clips), flutter_image_compress (for WebP conversion), record (for low-bitrate Opus/AAC voice notes)
• Caching & Video Playback: video_player + chewie (or media_kit), cached_network_image, flutter_cache_manager
• Live Voice Rooms: livekit_client
• Payments: flutter_paystack_plus (or url_launcher / WebView with Paystack Standard Checkout + Supabase Webhook verification)

5. Complete PostgreSQL Database Schema (Supabase)

Execute the following SQL script in the Supabase SQL Editor to initialize all tables, indexes, Row-Level Security (RLS) policies, and atomic Cowrie transaction functions.
sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. USERS & PROFILES (@username Privacy)
-- ==========================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL CHECK (username ~ '^[a-z0-9_]{3,20}$'),
    display_name TEXT NOT NULL,
    bio TEXT DEFAULT '',
    avatar_url TEXT,
    city TEXT DEFAULT 'Lagos',
    country_code TEXT DEFAULT 'NG',
    is_vendor BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_until TIMESTAMPTZ,
    cowries_balance INTEGER NOT NULL DEFAULT 50 CHECK (cowries_balance >= 0), -- 50 free welcome Cowries
    data_saver_mode BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 2. EPHEMERAL CHATS & MESSAGES
-- ==========================================
CREATE TABLE public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    is_group BOOLEAN DEFAULT FALSE,
    group_name TEXT,
    group_avatar_url TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.conversation_participants (
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    order_tag TEXT DEFAULT NULL CHECK (order_tag IN (NULL, 'Pending Payment', 'Paid', 'Dispatched', 'Resolved')),
    is_muted BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

-- Ephemeral relay table: rows are purged once delivered or after 7 days
CREATE TABLE public.ephemeral_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    message_type TEXT NOT NULL CHECK (message_type IN ('text', 'voice', 'image', 'video', 'reel_share', 'priority_ping')),
    encrypted_content TEXT, -- Text body or caption
    media_r2_key TEXT, -- Temporary Cloudflare R2 object key
    media_duration_sec INTEGER,
    is_priority_ping BOOLEAN DEFAULT FALSE,
    delivered_to UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

CREATE INDEX idx_ephemeral_conv ON public.ephemeral_messages(conversation_id, created_at);
CREATE INDEX idx_ephemeral_expires ON public.ephemeral_messages(expires_at);

-- ==========================================
-- 3. YARN ROOMS (Live Audio Hangouts)
-- ==========================================
CREATE TABLE public.yarn_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    joint_tag TEXT, -- Optional link to a +Joint (e.g., '+TechNaija')
    livekit_room_name TEXT UNIQUE NOT NULL,
    is_live BOOLEAN DEFAULT TRUE,
    listener_count INTEGER DEFAULT 1,
    total_cowries_sprayed INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

CREATE TABLE public.yarn_room_participants (
    room_id UUID REFERENCES public.yarn_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('host', 'speaker', 'listener')),
    hand_raised BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (room_id, user_id)
);

-- ==========================================
-- 4. REELS (Vertical Short-Form Video)
-- ==========================================
CREATE TABLE public.reels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL, -- Cloudflare R2 public URL
    thumbnail_url TEXT NOT NULL,
    caption TEXT DEFAULT '',
    city TEXT DEFAULT 'Lagos',
    duration_sec INTEGER NOT NULL,
    is_vendor_promo BOOLEAN DEFAULT FALSE,
    product_price_ngn INTEGER,
    boosted_until TIMESTAMPTZ,
    views_count INTEGER DEFAULT 0,
    hypes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    cowries_sprayed INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reels_feed ON public.reels(boosted_until DESC NULLS LAST, created_at DESC);

-- ==========================================
-- 5. +JOINTS (Community Boards & Hype/Fade)
-- ==========================================
CREATE TABLE public.joints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL CHECK (slug ~ '^[A-Za-z0-9_]{3,25}$'), -- Rendered as +slug
    description TEXT NOT NULL,
    creator_id UUID REFERENCES public.profiles(id),
    members_count INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.joint_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    joint_id UUID REFERENCES public.joints(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT DEFAULT '',
    media_urls TEXT[] DEFAULT '{}',
    hype_count INTEGER DEFAULT 1,
    fade_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    cowrie_awards INTEGER DEFAULT 0,
    pinned_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.joint_votes (
    post_id UUID REFERENCES public.joint_posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    vote_type TEXT NOT NULL CHECK (vote_type IN ('hype', 'fade')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE public.joint_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES public.joint_posts(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES public.joint_comments(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    hype_count INTEGER DEFAULT 1,
    fade_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 6. COWRIES WALLET & PAYSTACK LEDGER
-- ==========================================
CREATE TABLE public.cowrie_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    tx_type TEXT NOT NULL CHECK (tx_type IN (
        'paystack_topup',
        'welcome_bonus',
        'spend_boost_reel',
        'spend_boost_post',
        'spend_priority_ping',
        'spend_voice_to_text',
        'spend_verified_badge',
        'spray_sent',
        'spray_received'
    )),
    amount INTEGER NOT NULL, -- Positive for credit, negative for debit
    paystack_reference TEXT UNIQUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Atomic RPC Function to safely spend Cowries without race conditions
CREATE OR REPLACE FUNCTION public.spend_cowries(
    p_user_id UUID,
    p_amount INTEGER,
    p_tx_type TEXT,
    p_metadata JSONB DEFAULT '{}'
) RETURNS BOOLEAN AS $$
DECLARE
    current_bal INTEGER;
BEGIN
    SELECT cowries_balance INTO current_bal FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    IF current_bal IS NULL OR current_bal < p_amount THEN
        RETURN FALSE;
    END IF;

    UPDATE public.profiles
    SET cowries_balance = cowries_balance - p_amount,
        updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO public.cowrie_transactions (user_id, tx_type, amount, metadata)
    VALUES (p_user_id, p_tx_type, -p_amount, p_metadata);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
Use code with caution.

6. Backend Edge Functions & Integrations

The Arena.ai agent should implement the following three serverless Supabase Edge Functions (TypeScript/Deno) so secret keys (CLOUDFLARE_R2_SECRET_KEY, PAYSTACK_SECRET_KEY, LIVEKIT_API_SECRET) never touch the Flutter client binary.

6.1 Edge Function 1: get-r2-presigned-url

• Purpose: Generates a secure, time-limited (300 seconds) S3-compatible Presigned PUT URL for Cloudflare R2.
• Input Payload: { "folder": "reels" | "ephemeral_chat" | "avatars", "fileExtension": "mp4" | "m4a" | "webp", "contentType": "video/mp4" }
• Security Validation: Verifies the Supabase JWT token, checks file extension whitelist, and enforces max file size constraints (15 MB for Reels, 2 MB for voice notes/images).
• Output: { "uploadUrl": "https://<account>://...", "publicUrl": "https://kwikchat.ng...", "objectKey": "reels/uuid.mp4" }

6.2 Edge Function 2: paystack-webhook

• Purpose: Listens for Paystack charge.success webhook events when a user buys a Cowries bundle.
• Security Validation: Computes HMAC-SHA512 signature of the raw request body using PAYSTACK_SECRET_KEY and compares it against the x-paystack-signature header.
• Idempotency & Crediting: Checks cowrie_transactions for paystack_reference to prevent double-crediting. Maps the paid amount (50000 kobo -> 100 Cowries, 250000 kobo -> 550 Cowries, 500000 kobo -> 1200 Cowries, 1000000 kobo -> 3000 Cowries), increments profiles.cowries_balance, and inserts an audit log row.

6.3 Edge Function 3: transcribe-voice-note

• Purpose: Deducts 10 Cowries via spend_cowries() RPC, downloads the temporary voice note from R2, sends it to an AI speech-to-text endpoint (OpenAI Whisper / Groq Whisper with prompt context for Nigerian Pidgin, Yoruba, Hausa, and Igbo), and returns the text transcript to the user.

6.4 Scheduled Cron Cleanup (pg_cron / Cloudflare Worker)

• Runs every 6 hours to:
	1. Delete rows from public.ephemeral_messages where expires_at < NOW() or where array_length(delivered_to, 1) equals the total participant count of that conversation.
	2. Delete corresponding expired objects from the /ephemeral_chat/ prefix in Cloudflare R2.

7. Implementation Checklist for Arena.ai Engineering Agent

1. Initialize Flutter Project (kwikchat): Configure Dark (#0f1110 / #b8f226) and Light (#f6f8f7 / #658c08) ThemeData classes matching Section 2.1.
2. Set Up Local Storage (Drift / Isar): Create local tables for LocalConversations and LocalMessages so the Chats tab loads instantaneously offline.
3. Wire Supabase Auth & @username Onboarding: Build the splash screen (displaying the custom kwik speed-spark bubble logo and "No long talk. Just KwikChat." tagline), OTP login, and @username claim screen.
4. Build the 4-Tab Shell:
	• Tab 1 (Chats): Active Yarn Rooms horizontal bar + offline-first chat list + 1-on-1 chat screen with Opus voice recorder, Priority Ping toggle, and vendor order status tags.
	• Tab 2 (Reels): Full-screen vertical video player with For You / Naija tabs, Data-Saver Mode toggle, video_compress upload flow, and Message Vendor CTA.
	• Tab 3 (+ Joints): Community feed with +Joint tags, Hype / Fade vote buttons, nested comment threads, and Cowrie Award modal.
	• Tab 4 (Market & Wallet): Vendor storefront grid, Cowries balance card, Paystack checkout sheet (Starter Pouch, Hustler Bag, Oga Chest, Chief Vault), and Light/Dark theme switcher.
This complete specification is ready for you to copy and paste directly into the Arena.ai agent to start generating your code. Would you like me to also generate starter Flutter theme code (app_theme.dart) or the exact TypeScript code for the Cloudflare R2 & Paystack Edge Functions to include alongside this document?
