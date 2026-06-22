# RaceLine — Setup Guide

This guide covers everything needed to run the iOS app, web dashboard, and Supabase backend from scratch.

---

## Prerequisites

| Tool | Version |
|---|---|
| Xcode | 16+ |
| iOS device | 18.5+ (physical device for GPS/motion) |
| Node.js | 18+ |
| npm / pnpm | Latest |
| Supabase account | Free tier works |
| Vercel account (optional) | For web deployment |

---

## 1. Supabase Setup

### 1a. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and create a new project.
2. Note your **Project URL** and **anon key** from Settings → API.

### 1b. Run SQL migrations

In the Supabase Dashboard → SQL Editor, run each file in order:

```
supabase/migrations/001_schema.sql
supabase/migrations/002_rls_policies.sql
supabase/migrations/003_storage_policies.sql
```

Or use the Supabase CLI:
```bash
supabase db push
```

### 1c. Create storage buckets

In Supabase Dashboard → Storage, create these **private** buckets:
- `ride-photos`
- `bike-photos`
- `ride-telemetry`
- `maintenance-photos`

> **IMPORTANT:** All buckets must be **private** (not public). The SQL in `003_storage_policies.sql` creates the correct RLS policies, but you must create the buckets first.

### 1d. Configure Auth redirect URLs

In Supabase Dashboard → Authentication → URL Configuration:

**Site URL:**
```
https://YOUR_DOMAIN.com
```
*(Use `http://localhost:3000` for local development)*

**Redirect URLs (add all of these):**
```
https://YOUR_DOMAIN.com/auth/callback
http://localhost:3000/auth/callback
tread://auth/callback
```

> Once you purchase a domain, replace `YOUR_DOMAIN.com` with your actual domain everywhere.

### 1e. Enable email confirmations (optional but recommended)

In Supabase Dashboard → Authentication → Email Templates, customize the confirmation email to use your domain in links.

---

## 2. iOS App Setup

### 2a. Open in Xcode

```bash
open MotorcycleTrackShare.xcodeproj
```

### 2b. Configure Supabase credentials

Edit `MotorcycleTrackShare/SupabaseConfig.swift`:

```swift
enum SupabaseConfig {
    static let projectURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
    static let anonKey    = "YOUR_ANON_KEY"
}
```

> **Never commit real keys to a public repo.** For production, consider using a config file excluded from git, or Xcode build settings.

### 2c. Configure deep links (for auth callbacks)

In the Xcode project → Target → Info → URL Types, add:
- **Identifier:** `com.yourname.tread`
- **URL Schemes:** `tread`

This enables `tread://auth/callback` deep links for email confirmation and password reset on iOS.

### 2d. Build and run

- Select a **real iOS device** (GPS and motion sensors don't work in Simulator)
- Build with ⌘R
- Grant Location (Always or While Using) and Motion permissions when prompted

---

## 3. Web Dashboard Setup

### 3a. Install dependencies

```bash
cd web
npm install
```

### 3b. Configure environment

Copy the example env file:
```bash
cp .env.example .env.local
```

Edit `web/.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

### 3c. Run locally

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## 4. Deploy to Vercel

### 4a. Push to GitHub

```bash
git add .
git commit -m "feat: initial RaceLine setup"
git push origin main
```

### 4b. Import to Vercel

1. Go to [vercel.com](https://vercel.com) and import your GitHub repo.
2. Set **Root Directory** to `web`.
3. Add environment variables:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   NEXT_PUBLIC_SITE_URL=https://YOUR_DOMAIN.com
   ```
4. Deploy.

### 4c. Connect a custom domain

1. In Vercel → Project → Settings → Domains, add your domain.
2. Follow DNS instructions (CNAME or A record).
3. Update Supabase Auth redirect URLs to use your real domain (see step 1d).
4. Update `NEXT_PUBLIC_SITE_URL` in Vercel environment variables.

---

## 5. Production Checklist

Before going live, verify:

- [ ] Supabase RLS is enabled on all tables
- [ ] All storage buckets are **private**
- [ ] Auth redirect URLs include your production domain
- [ ] Auth redirect URLs do **not** include `localhost` in production
- [ ] `NEXT_PUBLIC_SITE_URL` set to production domain in Vercel
- [ ] No real keys committed to git
- [ ] Password reset email tested end-to-end
- [ ] Email confirmation tested end-to-end
- [ ] Account deletion tested (deletes all user data)
- [ ] Local-only mode tested (no network calls)
- [ ] Offline ride recording tested
- [ ] Sync retry tested after going offline then online

---

## Troubleshooting

**Auth redirect loops on web:** Make sure `NEXT_PUBLIC_SITE_URL` matches the exact URL you're accessing (include/exclude `www` consistently).

**iOS deep links not working:** Check URL scheme is registered in Info tab and that Supabase redirect URLs include `tread://auth/callback`.

**Cloud sync not uploading:** Check Supabase RLS policies are applied, buckets exist, and the user is logged in with a confirmed email.

**GPS not working:** Physical device required. Check Location permission is granted in iOS Settings.
