# RaceLine — Privacy & Security

RaceLine is designed around the principle that **your GPS route data is sensitive and should stay private by default**.

---

## Core Privacy Principles

1. **Local-only mode is always available** — no account required, ever.
2. **Cloud upload is opt-in** — nothing leaves the device without explicit user choice.
3. **Default cloud mode is summary-only** — distance, duration, speed, lean stats only. No GPS coordinates.
4. **Full route upload requires a separate, explicit choice** with a warning.
5. **Private buckets only** — all Supabase Storage buckets are private. No public URLs.
6. **Signed URLs** — photos and telemetry files are accessed only via expiring signed URLs.
7. **RLS enforced** — every database row and storage object is scoped to the authenticated user via `auth.uid()`.
8. **No third-party data sharing** — no analytics SDKs, ad networks, or tracking pixels in the iOS app or web dashboard.
9. **Account deletion** — users can delete all their data (rides, bikes, maintenance, photos, telemetry) at any time.
10. **Data export** — users can export their own data as JSONL or CSV.

---

## What Data Is Collected

### Local-only users
Nothing leaves the device. All data stored in the iOS app's sandboxed Documents directory.

### Signed-in users (summary-only mode, default)
The following is uploaded to Supabase:
- Email address (for auth)
- Ride stats: distance, duration, speed, lean angles, timestamps
- Bike info: nickname, make, model, year
- Maintenance records
- Ride name and notes/tags (if added)
- Ride photo (if chosen and cloud sync is on)

**Not uploaded in summary-only mode:**
- GPS route coordinates
- Raw telemetry JSONL

### Signed-in users (full route mode, opt-in)
Everything above, plus:
- Full GPS route as JSONL (lat/lon per sample)
- All motion sensor readings per sample

---

## Storage Architecture

| Bucket | Contents | Access |
|---|---|---|
| `ride-photos` | Ride cover photos | Private, signed URLs only |
| `bike-photos` | Bike profile photos | Private, signed URLs only |
| `ride-telemetry` | Raw JSONL telemetry | Private, signed URLs only |
| `maintenance-photos` | Maintenance receipts | Private, signed URLs only |

Storage path format:
```
{user_id}/rides/{ride_id}/photo.jpg
{user_id}/rides/{ride_id}/telemetry.jsonl
{user_id}/bikes/{bike_id}/photo.jpg
{user_id}/maintenance/{record_id}/receipt.jpg
```

Storage RLS ensures users can only read/write objects under their own `{user_id}/` prefix.

---

## Route Privacy Features

### Default behavior
- Routes are stored locally and never uploaded unless the user explicitly enables full route sync.
- Share cards show summary stats only; no route map by default.

### Route hiding (configurable)
Users can configure a start/end hiding distance. The first and last N miles/km of a route are trimmed from:
- Share card map previews
- Web dashboard route maps

Options: Off, 0.1 mi, 0.25 mi (default), 0.5 mi, 1.0 mi, custom

> **Important:** Route trimming applies to previews only. The original raw local file is never permanently modified unless the user explicitly chooses a "trim before upload" option (future feature).

### GPS metadata in photos
Photos taken with the iOS camera may contain GPS EXIF metadata. RaceLine strips EXIF GPS data from photos before uploading to Supabase. Photos stored locally retain their original metadata.

---

## Row Level Security (RLS)

Every table has RLS enabled with a `user_id = auth.uid()` policy:

```sql
-- Example: rides table
CREATE POLICY "Users can only access own rides"
  ON rides FOR ALL
  USING (user_id = auth.uid());
```

This means:
- A logged-in user can only SELECT, INSERT, UPDATE, DELETE their own rows.
- Even with a valid JWT, a user cannot access another user's data.
- The Supabase anon key alone is insufficient — a valid session is required.

---

## Account Deletion

Users can delete their account from both the iOS app (Profile → Settings → Delete Account) and the web dashboard (Account → Delete Account).

Deletion process:
1. User confirms intent with a destructive confirmation dialog.
2. App/web calls a Supabase Edge Function (`/functions/v1/delete-account`).
3. The Edge Function (using service role key, server-side only):
   - Deletes all rides, bikes, maintenance records from the database.
   - Deletes all storage objects under `{user_id}/` in all buckets.
   - Deletes the auth user record.
4. Local app data is cleared after successful deletion.

> **The service role key is never exposed to the iOS app or web client.** It exists only in the Edge Function environment.

---

## Secrets Management

| Secret | Where stored | Notes |
|---|---|---|
| Supabase anon key | iOS: `SupabaseConfig.swift` | Safe to use client-side with RLS |
| Supabase anon key | Web: `.env.local` / Vercel env | Safe to use client-side with RLS |
| Supabase service role key | Edge Function env only | Never in client code |
| Supabase URL | Both clients | Not secret |

**Never commit:**
- `.env` files
- `.env.local` files
- Files containing real API keys

---

## Supabase Auth Security

- Email/password authentication only for MVP.
- Email confirmation required before full cloud sync is enabled.
- Password reset via email with expiring link.
- JWT tokens managed by the Supabase client SDK.
- Sessions stored in iOS keychain (Supabase SDK handles this).
- Sessions stored in browser secure storage on web.

---

## Future Security Improvements (Roadmap)

- Apple Sign-In
- Google Sign-In
- TOTP / 2FA via Supabase Auth
- Telemetry compression with client-side encryption option
- Trim-before-upload option for permanent route privacy
- Public shared ride pages with explicit user consent and no GPS data by default
