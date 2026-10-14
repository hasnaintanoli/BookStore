const FIREBASE_PROJECT = 'bookstore-fe6f2';
const DATABASE_URL = 'https://bookstore-fe6f2-default-rtdb.firebaseio.com';
const OWNER_UID = '6W2W5WzGMiWG6580Q5ET4iS4y903';
const BUCKET = 'book-covers';
const MAX_BYTES = 20 * 1024 * 1024;
const GOOGLE_KEYS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

class Failure extends Error {
  constructor(readonly status: number, message: string) { super(message); }
}
function reply(status: number, body: unknown) {
  return Response.json(body, { status, headers: { ...cors, 'Cache-Control': 'no-store' } });
}
function decode(segment: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]+$/.test(segment)) throw new Failure(401, 'Please sign in again.');
  const normalized = segment.replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return Uint8Array.from(raw, (char) => char.charCodeAt(0));
}
type FirebaseClaims = {
  sub: string; aud: string; iss: string; exp: number; iat: number;
  auth_time: number; email_verified?: boolean; admin?: boolean;
};
let cachedKeys: (JsonWebKey & { kid: string; alg: string })[] = [];
let keysExpire = 0;
let keysFetchedAt = 0;
let keysRequest: Promise<void> | null = null;
async function refreshKeys() {
  if (!keysRequest) {
    keysRequest = (async () => {
      const response = await fetch(GOOGLE_KEYS, { signal: AbortSignal.timeout(8000) });
      if (!response.ok) throw new Failure(503, 'Sign-in verification is unavailable. Please retry.');
      const data = await response.json();
      cachedKeys = data.keys;
      keysFetchedAt = Date.now();
      const maxAge = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] ?? 300);
      keysExpire = Date.now() + Math.min(maxAge, 3600) * 1000;
    })().catch(() => {
      throw new Failure(503, 'Sign-in verification is unavailable. Please retry.');
    }).finally(() => { keysRequest = null; });
  }
  await keysRequest;
}

async function verifyFirebase(token: string): Promise<FirebaseClaims> {
  try {
    if (token.length > 16000) throw new Failure(401, 'Please sign in again.');
    const parts = token.split('.');
    if (parts.length !== 3) throw new Failure(401, 'Please sign in again.');
    const header = JSON.parse(new TextDecoder().decode(decode(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(decode(parts[1]))) as FirebaseClaims;
    if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
      throw new Failure(401, 'Please sign in again.');
    }
    if (Date.now() >= keysExpire) await refreshKeys();
    let jwk = cachedKeys.find((key) => key.kid === header.kid && key.alg === 'RS256');
    if (!jwk) {
      // Unknown keys do not cause an unbounded refresh for every invalid token.
      if (Date.now() - keysFetchedAt > 60000) await refreshKeys();
      jwk = cachedKeys.find((key) => key.kid === header.kid && key.alg === 'RS256');
    }
    if (!jwk) throw new Failure(401, 'Please sign in again.');
    const key = await crypto.subtle.importKey('jwk', jwk,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key,
      decode(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
    const now = Math.floor(Date.now() / 1000);
    if (!valid || claims.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT}` ||
        claims.aud !== FIREBASE_PROJECT || typeof claims.sub !== 'string' ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(claims.sub) ||
        !Number.isFinite(claims.exp) || claims.exp <= now ||
        !Number.isFinite(claims.iat) || claims.iat > now + 30 ||
        !Number.isFinite(claims.auth_time) || claims.auth_time > now + 30 ||
        claims.email_verified !== true) {
      throw new Failure(401, 'Please sign in with a verified account.');
    }
    return claims;
  } catch (error) {
    if (error instanceof Failure) throw error;
    throw new Failure(401, 'Please sign in again.');
  }
}

async function requireAdmin(claims: FirebaseClaims, token: string) {
  // Read current access flags on every upload. Profile role is never authority.
  const url = new URL(`${DATABASE_URL}/accountAccess/${claims.sub}.json`);
  url.searchParams.set('auth', token);
  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Failure(403, 'Administrator access could not be verified.');
  const flags = (await response.json()) ?? {};
  if (flags.disabled === true || flags.removed === true ||
      !(flags.admin === true || (claims.sub === OWNER_UID && claims.admin === true))) {
    throw new Failure(403, 'Only active bookstore administrators can upload covers.');
  }
}

async function readImage(request: Request): Promise<Uint8Array> {
  const declared = Number(request.headers.get('content-length'));
  if (declared > MAX_BYTES) throw new Failure(413, 'Choose an image smaller than 20 MB.');
  if (!request.body) throw new Failure(400, 'Choose a cover image.');
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > MAX_BYTES) {
        await reader.cancel();
        throw new Failure(413, 'Choose an image smaller than 20 MB.');
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  if (!length) throw new Failure(400, 'Choose a cover image.');
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}
function imageType(bytes: Uint8Array) {
  if (bytes.length >= 12 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 &&
      bytes[bytes.length - 2] === 255 && bytes[bytes.length - 1] === 217) {
    return { mime: 'image/jpeg', extension: 'jpg' };
  }
  if (bytes.length >= 33 && [137,80,78,71,13,10,26,10].every((b,i) => bytes[i] === b) &&
      new TextDecoder().decode(bytes.slice(12, 16)) === 'IHDR') {
    return { mime: 'image/png', extension: 'png' };
  }
  if (bytes.length >= 20 && new TextDecoder().decode(bytes.slice(0,4)) === 'RIFF' &&
      new TextDecoder().decode(bytes.slice(8,12)) === 'WEBP') {
    return { mime: 'image/webp', extension: 'webp' };
  }
  throw new Failure(415, 'Choose a JPG, PNG or WebP image.');
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return reply(405, { error: 'Use POST to upload a cover.' });
  try {
    const auth = request.headers.get('authorization')?.match(/^Bearer ([^\s]+)$/i);
    if (!auth) throw new Failure(401, 'Please sign in again.');
    const claims = await verifyFirebase(auth[1]);
    await requireAdmin(claims, auth[1]);
    const bytes = await readImage(request);
    const type = imageType(bytes);
    if (request.headers.get('content-type')?.split(';')[0].trim() !== type.mime) {
      throw new Failure(415, 'Choose a JPG, PNG or WebP image.');
    }
    // Content-addressed names make retries safe and never overwrite saved covers.
    const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
      (byte) => byte.toString(16).padStart(2, '0')).join('');
    const path = `${claims.sub}/${hash}.${type.extension}`;
    const base = Deno.env.get('SUPABASE_URL');
    const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
    const secret = secretKeys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!base || !secret) throw new Failure(503, 'Cover storage is unavailable. Please retry.');
    const headers: Record<string, string> = {
      apikey: secret, 'Content-Type': type.mime,
      'Cache-Control': 'max-age=31536000', 'x-upsert': 'false',
    };
    if (secret.startsWith('eyJ')) headers.Authorization = `Bearer ${secret}`;
    const upload = await fetch(`${base}/storage/v1/object/${BUCKET}/${path}`, {
      method: 'POST', headers, body: bytes, signal: AbortSignal.timeout(30000),
    });
    if (!upload.ok) {
      const detail = await upload.json().catch(() => ({}));
      // Storage reports existing content as 400/409; other errors are never success.
      if (!([400,409].includes(upload.status) &&
          (detail.error === 'Duplicate' || detail.message === 'The resource already exists'))) {
        throw new Failure(upload.status === 413 ? 413 : 502, 'Cover could not be uploaded. Please retry.');
      }
    }
    return reply(200, { url: `${base}/storage/v1/object/public/${BUCKET}/${path}` });
  } catch (error) {
    if (error instanceof Failure) return reply(error.status, { error: error.message });
    // Never log request URLs, auth tokens, privileged keys or upstream responses.
    return reply(503, { error: 'Cover upload is unavailable. Please retry.' });
  }
});
