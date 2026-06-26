# RaceLine — Production / TestFlight / App Store Checklist

Generated during the production-readiness pass on 2026-06-26.
Everything below is either **done by code**, **action required from you**, or **rejection risk to be aware of**.

---

## 1. What changed in this pass (commit `c886f02`)

| Area | Change |
|---|---|
| Onboarding | New `IntroTutorialView` — 7-page first-launch walkthrough explaining what RaceLine does, with inline buttons that trigger the location / motion / notification system prompts at the right moment with context. Shown once per device; re-runnable from Settings. |
| Notification prompt | Removed the eager request that fired on every cold launch; now requested as part of the tutorial. |
| Info.plist permission strings | Rewrote location, motion, camera, photo-library descriptions to be specific about what RaceLine uses each for and when. App-Store-compliant tone. |
| LocationService | Now exposes `authorizationStatus` + `isPermissionBlocked`; stops re-prompting after the user decides. |
| Start Ride | Blocks when location is denied or restricted, shows an alert with a deep link into iOS Settings → Privacy → Location. |
| Settings | New "Show Intro Tutorial" row in a Help section. About row now shows `version (build)` instead of just version. |

All other previously-working features were left untouched.

---

## 2. App Store Connect — manual steps you own

These cannot be done from code; do them in **App Store Connect** and **Apple Developer Portal**.

### Before first archive upload

1. **App Store Connect → My Apps → +** → create a new app:
   - Platform: iOS
   - Name: **RaceLine**
   - Primary language: English (U.S.)
   - Bundle ID: `com.manangandhi.MotorcycleTrackShare` (already registered)
   - SKU: pick anything unique to you (e.g. `raceline-ios-2026`)
   - User access: Full Access
2. **App Information** tab:
   - Subtitle (optional, 30 char): e.g. "Motorcycle telemetry"
   - Primary category: **Sports** (Health & Fitness is also valid)
   - Secondary category: **Navigation** (optional)
   - Content Rights: confirm you own all the content
   - Age Rating: complete the questionnaire — there's no objectionable content; should come out 4+

### Pricing and Availability

- Free, available in all territories (unless you want to limit).
- Family Sharing: enabled is fine.

### App Privacy (the "nutrition labels")

Apple requires you to declare what data your app collects. RaceLine's actual collection:

| Data type | Collected | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| **Email address** | Yes (via Apple/Google sign-in) | Yes | No | App functionality (account) |
| **Name** | Yes (display name) | Yes | No | App functionality (personalisation) |
| **User ID** | Yes (Supabase UUID) | Yes | No | App functionality (auth) |
| **Precise location** | Yes (only during recording) | Yes | No | App functionality (ride recording) |
| **Photos** | Yes (only if user attaches one) | Yes | No | App functionality (ride photos) |
| **Sensor data** (motion) | Yes (only during recording) | Yes | No | App functionality (lean angle, braking) |
| **Other usage data** (ride summaries) | Yes | Yes | No | App functionality |

Fill out App Store Connect → App Privacy → Get Started with the above. **No data is used for tracking, and we do not share with third parties for advertising.**

### Version Release

- Release manually after approval (so you can stage TestFlight first).
- Pricing: Free.

### Sign in with Apple

App Store Connect won't approve the app for App Review if you have a competing third-party login (like Google) but don't *also* offer Sign in with Apple. RaceLine offers both, so you're fine.

### Sandbox testing

Before submitting, log into App Store Connect → Users and Access → **Sandbox** and create a sandbox tester account. This is useful for testing without burning your own Apple ID.

---

## 3. Privacy Policy + Terms

- **Privacy Policy URL** required in App Store Connect → App Information.
  - You already host one at **`https://racelineapp.com/privacy`** ✅
- **Terms of Service** — not required by Apple for a free app with no IAP, but a good-faith addition. If you want, create `/terms` on the web with standard boilerplate. Not blocking.
- **Support URL** required: just point it at `https://racelineapp.com` or create a simple `/support` page with your email.
- **Marketing URL** optional.

---

## 4. Things still to set up server-side

| Item | Where | Status |
|---|---|---|
| Apple Sign in with Apple — enabled on App ID | Apple Developer Portal | ✅ Done |
| Apple Sign in with Apple — Supabase configured | Supabase Dashboard → Auth → Providers → Apple | ✅ Done |
| Google OAuth — Supabase configured | Supabase Dashboard → Auth → Providers → Google | ✅ Done |
| Domain `racelineapp.com` → Vercel | Namecheap DNS + Vercel | ✅ Done |
| Supabase Site URL = `https://racelineapp.com` | Supabase Dashboard | ✅ Done |
| Apple Sign in with Apple **for the web** | Apple Developer (Services ID + .p8 key) + Supabase | ⏳ Optional — currently iOS-only |
| `delete-account` Edge Function deployed | Supabase | ✅ Done |
| 10-ride cloud limit trigger | Supabase migration 005 | ✅ Done |

---

## 5. Rejection-risk warnings

Pre-empt these — Apple reviewers will check them.

| Risk | Severity | Mitigation |
|---|---|---|
| **"App requires camera/photos but won't tell me why"** | High | We rewrote all `Usage Description` strings to explain exactly what each permission is used for. ✅ |
| **"Sign in with Apple required when offering third-party sign-in"** | High | Both are offered. ✅ |
| **"Account deletion path missing"** | High | Profile → Delete Account is wired and deletes everything via Edge Function. ✅ |
| **"App crashes on launch with no data"** | High | Cold-launch path goes intro → auth → onboarding → ContentView. All loads from `Documents/` are wrapped in try? and fall back to empty arrays. RideStore, GarageStore, MaintenanceStore all handle empty state. |
| **"Unfinished beta-quality UI"** | Medium | Recommend doing a full real-device pass before submission. The TestFlight checklist below covers it. |
| **"Track mode could be mistaken for a lap timer"** | Medium | We added the "not a lap timer or official timing device. Use only on closed circuits" alert before starting a track ride. ✅ |
| **"Location used without justification"** | Medium | Permission string + intro tutorial make it explicit. ✅ |
| **"Background location without `UIBackgroundModes`"** | N/A | RaceLine keeps the screen on during recording (`isIdleTimerDisabled`) and uses When-In-Use only. No background entitlement needed; no review extra scrutiny. |
| **"Trademark issues with bike makes"** | Low | Make/model names are user-entered and pulled from the open NHTSA vehicle API. Not your branding. Safe. |
| **"Notification permission requested on launch without explanation"** | Low | Removed; now part of the intro tutorial. ✅ |

---

## 6. TestFlight checklist — run on a real iPhone before uploading

Make a clean install, then walk through every flow:

### Cold launch
- [ ] First launch shows intro tutorial; can swipe through 7 pages
- [ ] "Allow Location" button on page 4 triggers the iOS prompt
- [ ] "Allow Motion" button on page 5 triggers the iOS prompt
- [ ] "Allow Notifications" button on page 6 triggers the iOS prompt
- [ ] "Get Started" on page 7 advances to AuthView
- [ ] Re-launching the app skips the tutorial

### Auth
- [ ] Sign in with Apple — Face ID prompts once, lands in app
- [ ] Sign in with Google — Safari opens, returns cleanly
- [ ] Cancel Apple sign-in mid-flow → stays on Auth screen, no crash
- [ ] Cancel Google sign-in mid-flow → stays on Auth screen
- [ ] Sign out from Profile → returns to AuthView
- [ ] After sign out, sign back in → loads existing rides

### Onboarding (first time per user)
- [ ] Display name pre-filled from Apple/Google (Apple) or blank (Google)
- [ ] Units segmented control responds
- [ ] Continue button disabled when name empty
- [ ] Submitting transitions to main app
- [ ] Second sign-in skips onboarding

### Permissions denied
- [ ] Deny location in Settings → tap Start Ride → "Location Access Needed" alert appears with "Open Settings" link
- [ ] Tapping Open Settings opens iOS Settings to RaceLine page

### Ride recording (the most important one)
- [ ] Map loads, shows your location
- [ ] Calibrate Lean Sensor button tappable
- [ ] Tap Start Ride → "Choose Ride Type" sheet appears
- [ ] Pick Street → ride begins, timer ticks, distance accrues
- [ ] Pick Track → warning appears, then ride begins
- [ ] Speed updates in real time
- [ ] Lean angle updates in real time as you tilt phone
- [ ] Screen stays on (doesn't dim)
- [ ] Lock phone → unlock → ride is still recording (timer kept ticking)
- [ ] Background app → re-open → ride still recording
- [ ] Tap Stop Ride → "Save this ride?" confirmation
- [ ] Save → name sheet appears with default name
- [ ] Add photo, bike, notes, tags → Save → ride appears in Rides list
- [ ] Ride syncs to web within ~30s if cloud sync enabled

### Edge cases
- [ ] Record ride shorter than 5 seconds → "Ride too short to save" alert
- [ ] Record ride with same name as existing → "Ride name already exists"
- [ ] Try to upload 11th cloud ride → settings shows "Ride limit reached (10/10). Delete a ride to make room"
- [ ] Tap Start Ride twice rapidly → only one ride starts
- [ ] No internet → ride still records, syncs when back online

### Bike + maintenance flows
- [ ] Add Bike — year is required, make/model from picker, save
- [ ] Edit Bike — changes persist
- [ ] Add Maintenance — type, optional title (only for Custom), date, mileage reminder, receipt photo, save
- [ ] Edit Maintenance — changes persist

### Sharing
- [ ] Tap Share on a ride → ShareCardScreen with current ride preselected
- [ ] Pick photo, customize colors, tap export → iOS share sheet says "RaceLine"

### Account
- [ ] Profile shows display name / email / sync badge
- [ ] Settings → Show Intro Tutorial → tutorial replays
- [ ] Settings → About shows correct version and build
- [ ] Delete Account → confirms, wipes data, returns to AuthView

### Performance + battery
- [ ] After a 30+ minute ride: app responsive, battery drain reasonable (~15-25% per hour with screen on)
- [ ] After a long ride: app didn't crash, all data saved

---

## 7. How to archive and upload to App Store Connect

Run on Mac with Xcode 16+:

```bash
# Optional but recommended — clean before archiving
xcodebuild clean -project MotorcycleTrackShare.xcodeproj -scheme MotorcycleTrackShare
```

Then in Xcode:

1. **Top destination dropdown** → select **"Any iOS Device (arm64)"** (not a simulator)
2. Make sure **Signing & Capabilities** has your team selected, "Automatically manage signing" checked, and no red errors
3. **Product → Archive** (⇧⌘B doesn't work for this; use the menu)
4. Wait for build — usually 1-2 minutes
5. The Organizer window opens automatically
6. Select your new archive → **Distribute App**
7. Pick **App Store Connect** → Next
8. Pick **Upload** → Next
9. Leave defaults (Upload symbols, manage signing) → Next
10. Review → **Upload**

Apple processes the build for ~5-30 minutes. You'll get an email when it's ready in TestFlight.

After processing:
- **App Store Connect → TestFlight** → your build appears
- Add yourself (and friends) as Internal Testers
- They'll get an email + TestFlight app invite

---

## 8. Submitting to the App Store proper

After TestFlight, when you're confident:

1. **App Store Connect → your app → Prepare for Submission**
2. Fill in:
   - **Description** (up to 4000 chars) — what RaceLine does, key features
   - **Keywords** (100 chars, comma-separated) — e.g. `motorcycle,ride,track,gps,telemetry,lean,speed,maintenance`
   - **Support URL**: `https://racelineapp.com`
   - **Marketing URL** (optional): `https://racelineapp.com`
3. **Screenshots** — required sizes:
   - 6.7" iPhone (iPhone 15/16 Pro Max): **mandatory**, at least 3
   - 6.1" iPhone (iPhone 15/16): optional but recommended
   - iPad screenshots only required if the app is iPad-targeted (RaceLine is iPhone-only-ish)
   - Take them in the simulator: ⌘S
4. **Promotional Text** (optional) — short blurb shown above the description
5. **What's New in this Version** — for v1.0, write something like "Welcome to RaceLine 1.0"
6. **App Review Information**:
   - Sign-in info: provide a test account (Apple sandbox account works) so reviewers can sign in
   - Notes: explain that the app uses location for ride recording, never in background
   - Phone number + email
7. **Version Release**: Manual release after approval
8. **Submit for Review**

First reviews typically take **24-72 hours**. Be ready to respond fast if rejected.

---

## 9. Things deliberately *not* changed in this pass (and why)

| Item | Status |
|---|---|
| Print statement noise | 27 prints exist in catch blocks. None log sensitive data (no tokens, emails, GPS). Acceptable for App Store; wrap in `#if DEBUG` later if you want zero noise in production logs. |
| `tread://` URL scheme | Behind the scenes; works fine; renaming requires coordinated Supabase + Info.plist update. Low priority. |
| Xcode target name (`MotorcycleTrackShare`) and bundle ID | Renaming breaks signing, Supabase OAuth allowlists, and provisioning. Intentionally left as internal name. |
| Dark mode only (`.preferredColorScheme(.dark)`) | RaceLine is dark-first by design. Adding light mode would require restyling all hardcoded color tokens; not blocking submission. |
| Background location | We don't request it; screen stays on via `isIdleTimerDisabled`. Means less battery vs background, but no privacy-review extra scrutiny. |
| Crash reporting / analytics | None added. Apple's built-in Crashes dashboard in App Store Connect covers basic crash signals. Add Sentry later if you want richer signal. |

---

## 10. If you hit a rejection

Most common rejections for an app like this:

- **"Guideline 5.1.1 - Permissions"** — re-read your permission strings. We pre-wrote good ones, but if reviewer complains, expand the description further.
- **"Guideline 2.1 - Performance"** — usually crashes on launch. Test the cold-launch path on multiple iOS versions.
- **"Guideline 4.0 - Design"** — UI bugs, dead buttons. The TestFlight checklist catches these.
- **"Guideline 5.1.1(v) - Account Sign-In"** — must offer Sign in with Apple if you offer Google. Done.
- **"Guideline 4.5.4 - Push Notifications"** — must not require notifications for core functionality. We don't.

You can reply to the rejection in App Store Connect and provide context. Usually a clear explanation resolves things in one round.

---

## Quick reference

| Thing | Value |
|---|---|
| App name (user-facing) | RaceLine |
| Xcode target / bundle | `MotorcycleTrackShare` / `com.manangandhi.MotorcycleTrackShare` |
| Marketing version | 1.0 |
| Build number | 1 (bump before each TestFlight upload) |
| Apple Developer Team ID | `3244DXH2Z8` |
| Supabase project | `kbogzpfxfexfzozcgfwb` |
| Web | `https://racelineapp.com` |
| Privacy policy | `https://racelineapp.com/privacy` |
| Support | `https://racelineapp.com` (use your own email for App Review) |
