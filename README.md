# Tread

**Privacy-first motorcycle ride analytics for iOS, with a companion web dashboard.**

Tread is a motorcycle ride tracking app that lets you record rides with GPS and motion data, manage your garage, track maintenance, generate share cards, and view analytics on the web — all while keeping your sensitive route data private by default.

---

## Why I Built This

I wanted a ride tracker that actually respects privacy. Most apps upload your entire GPS route to their servers without asking. Tread defaults to cloud summary only — your exact route stays on your phone unless you explicitly choose to share it. Built as a portfolio project to demonstrate full-stack iOS + web development with thoughtful product design.

---

## Features

### iOS App
- GPS + motion data ride recording (speed, lean angle, roll, pitch, yaw)
- Street and Track ride modes
- Offline-first — rides save locally without internet
- Flexible cloud sync: local only, summary only, or full route
- Garage management with per-bike statistics
- Maintenance tracking with due-soon reminders
- Ride notes, tags, and filtering
- Share card generation
- Route privacy controls — hide start/end of route from share cards and maps
- Local-only mode — no account required
- Dark and light mode

### Web Dashboard
- View cloud-synced rides with stats and maps
- Ride analytics charts (speed, lean, elevation over time)
- Garage and bike stats overview
- Maintenance history
- Share card generation and download
- Account management

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS | Swift, SwiftUI, CoreLocation, CoreMotion |
| Backend | Supabase (Auth, PostgreSQL, Storage) |
| Web | Next.js, TypeScript, Tailwind CSS |
| Maps | Leaflet / OpenStreetMap |
| Charts | Recharts |
| Deployment | Vercel |

---

## Architecture

```
tread/
├── MotorcycleTrackShare/       iOS app (Xcode project)
│   ├── Models/                 Data models
│   ├── Services/               Business logic, storage, sync
│   └── Views/                  SwiftUI views
├── web/                        Next.js web dashboard
│   ├── app/                    Pages (App Router)
│   ├── components/             Shared UI components
│   └── lib/                    Supabase client, utilities
├── supabase/
│   ├── migrations/             SQL migration files
│   ├── functions/              Edge Functions
│   └── README.md               Schema documentation
├── docs/
│   ├── SETUP.md                Full setup guide
│   ├── PRIVACY_SECURITY.md     Privacy architecture
│   └── ROADMAP.md              Future features
└── README.md
```

### Data Flow

```
iOS App                         Supabase
─────────────────────────────────────────────────
Record ride
  └─ Save locally (always)
       └─ If cloud sync ON:
            ├─ Summary → rides table (always)
            ├─ Photo   → ride-photos bucket (if photo exists)
            └─ Telemetry → ride-telemetry bucket (if "full" mode)

Web Dashboard
  └─ Reads rides table
       ├─ Shows summary stats (always available)
       ├─ Shows photo (if uploaded)
       └─ Shows route map + charts (if full telemetry uploaded)
```

---

## Screenshots

> Coming soon — see `docs/screenshots/`

---

## Setup

See [`docs/SETUP.md`](docs/SETUP.md) for full instructions.

**Quick start:**

1. Clone the repo
2. Open `MotorcycleTrackShare.xcodeproj` in Xcode
3. Set your Supabase URL and anon key in `MotorcycleTrackShare/SupabaseConfig.swift`
4. Run the SQL migrations from `supabase/migrations/` in Supabase Dashboard
5. Configure storage buckets per `supabase/README.md`
6. Build and run on a real device (GPS/motion requires physical hardware)

---

## Environment Variables

### iOS
Set in `MotorcycleTrackShare/SupabaseConfig.swift` (do not commit real keys to public repos):
```swift
static let projectURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
static let anonKey    = "YOUR_ANON_KEY"
```

### Web (`web/.env.local`)
```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
NEXT_PUBLIC_SITE_URL=https://YOUR_DOMAIN.com
```

---

## Privacy & Security

- **Local-only mode** — no account needed, all data stays on device
- **Default cloud mode** — summary stats only (no GPS route)
- **Full route sync** — opt-in only, with explicit warning
- **Private storage** — all Supabase buckets are private; signed URLs only
- **RLS enforced** — users can only access their own data
- **Route hiding** — configurable start/end distance masking for share cards

See [`docs/PRIVACY_SECURITY.md`](docs/PRIVACY_SECURITY.md) for full details.

---

## Possible Domains

- `ridetread.app`
- `gettread.app`
- `treadrides.com`
- `treadmoto.com`
- `treadtracker.app`
- `trytread.app`
- `treadgarage.com`

---

## Roadmap

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for planned features.

---

## Resume Bullets

> Copy-paste ready for portfolio/resume use:

- Built **Tread**, a privacy-first iOS motorcycle tracking app in SwiftUI with CoreLocation/CoreMotion sensor fusion, offline-first ride recording, and configurable cloud sync via Supabase
- Designed and implemented an offline-first sync architecture with a pending-upload queue, retry logic, and per-ride storage mode selection (local, summary-only, or full GPS telemetry)
- Built a companion Next.js + TypeScript web dashboard with Supabase Auth, real-time ride analytics (Recharts), interactive route maps (Leaflet/OpenStreetMap), and server-side RLS enforcement
- Implemented end-to-end privacy architecture: private storage buckets, signed URLs, route-trimming for share cards, and configurable GPS data exposure
- Deployed web app to Vercel with Supabase Auth callback, protected routes, and account self-deletion via Edge Function

---

*Built by [@manangandhi03146](https://github.com/manangandhi03146)*
