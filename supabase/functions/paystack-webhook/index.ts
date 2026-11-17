// ============================================================================
// paystack-webhook — credits Cowries after a verified payment.
//
// Deploy:  supabase functions deploy paystack-webhook --no-verify-jwt
// Secrets: supabase secrets set PAYSTACK_SECRET_KEY=sk_live_xxx
//
// Why --no-verify-jwt: Paystack cannot send a Supabase JWT. Authenticity comes
// from the HMAC-SHA512 signature instead, which is checked before anything else
// touches the database.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const PAYSTACK_SECRET = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

/** Naira price (in kobo) → Cowries, including bundle bonuses. */
const BUNDLES: Record<number, { cowries: number; label: string }> = {
  50000: { cowries: 100, label: "Starter Pouch" },
  250000: { cowries: 550, label: "Hustler Bag" },
  500000: { cowries: 1200, label: "Oga Chest" },
  1000000: { cowries: 3000, label: "Chief Vault" },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function hmacSha512(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!PAYSTACK_SECRET) return json({ error: "webhook_not_configured" }, 500);

  // Raw body first: re-serialising JSON breaks the signature.
  const raw = await req.text();
  const expected = await hmacSha512(PAYSTACK_SECRET, raw);
  const provided = req.headers.get("x-paystack-signature") ?? "";
  if (expected.length !== provided.length || expected !== provided) {
    return json({ error: "invalid_signature" }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (event.event !== "charge.success") {
    // Acknowledge everything else so Paystack stops retrying.
    return json({ ok: true, ignored: event.event ?? "unknown" });
  }

  const data = (event.data ?? {}) as Record<string, unknown>;
  const amount = Number(data.amount ?? 0);
  const reference = String(data.reference ?? "");
  const email = String((data.customer as Record<string, unknown> | undefined)?.email ?? "");
  const metadata = (data.metadata ?? {}) as Record<string, unknown>;

  const bundle = BUNDLES[amount];
  if (!bundle) return json({ ok: true, ignored: "unknown_bundle", amount });
  if (!reference) return json({ error: "missing_reference" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // The checkout must put the buyer's uid in metadata.user_id. Never trust the
  // email: matching on email would let a different account claim the credit.
  const userId = typeof metadata.user_id === "string" ? metadata.user_id : "";
  if (!userId) {
    console.warn("no user_id in metadata", { reference, email });
    // Acknowledge so Paystack stops retrying; reconcile manually by reference.
    return json({ ok: true, ignored: "missing_user_id", reference });
  }

  // Idempotent by reference: replaying the same webhook credits nothing extra.
  const { data: balance, error } = await admin.rpc("grant_cowries", {
    p_user_id: userId,
    p_amount: bundle.cowries,
    p_kind: "paystack_topup",
    p_ref: `paystack:${reference}`,
    p_metadata: { bundle: bundle.label, amount_kobo: amount, email },
  });

  if (error) {
    console.error("grant_cowries failed", error);
    // Non-2xx makes Paystack retry — correct for transient DB failures.
    return json({ error: "credit_failed" }, 500);
  }

  return json({ ok: true, credited: bundle.cowries, balance, reference });
});
