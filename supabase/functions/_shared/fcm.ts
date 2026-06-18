// FCM HTTP v1 push helper (BILLING_BUCKET1_BUILD_PROMPT.md §3) — service-account
// (OAuth2) auth + a single-token send. Used by the send-reminders engine.
//
// Secrets (set via `supabase secrets set`):
//   FCM_SERVICE_ACCOUNT — the service-account JSON (one line) from the Firebase
//                         console (Project settings → Service accounts → Generate
//                         new private key). Must include client_email + private_key.
//   FCM_PROJECT_ID      — the Firebase project id (falls back to the JSON's project_id).

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id?: string;
  token_uri?: string;
}

// Cache the OAuth token across invocations of a warm instance (valid ~1h).
let cached: { token: string; exp: number } | null = null;

export async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;

  const aud = sa.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claim))}`;
  const key = await importKey(sa.private_key);
  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64urlBytes(new Uint8Array(sigBuf))}`;

  const resp = await fetch(aud, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=${
      encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")
    }&assertion=${jwt}`,
  });
  const data = await resp.json();
  if (!resp.ok) throw new Error(`fcm token: ${resp.status} ${JSON.stringify(data)}`);
  cached = { token: data.access_token, exp: now + (data.expires_in ?? 3600) };
  return cached.token;
}

export interface FcmResult {
  ok: boolean;
  status: number;
  /// The token is no longer valid (UNREGISTERED) → caller should delete it.
  unregistered: boolean;
}

export async function sendPush(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<FcmResult> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: "normal" },
        },
      }),
    },
  );
  if (resp.ok) return { ok: true, status: resp.status, unregistered: false };
  const text = await resp.text();
  console.error("fcm send failed", resp.status, text);
  // 404 UNREGISTERED (stale token) — also treat a 400 whose body says UNREGISTERED.
  const unregistered = resp.status === 404 ||
    (resp.status === 400 && text.includes("UNREGISTERED"));
  return { ok: false, status: resp.status, unregistered };
}

// ── helpers ─────────────────────────────────────────────────────────────────
async function importKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function b64url(s: string): string {
  return b64urlBytes(new TextEncoder().encode(s));
}

function b64urlBytes(bytes: Uint8Array): string {
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
