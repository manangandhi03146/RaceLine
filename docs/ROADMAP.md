# Tread — Roadmap

Current status: **Private Beta (MVP)**

---

## Now (MVP)

- [x] iOS ride recording (GPS + motion)
- [x] Offline-first local storage
- [x] Garage / bike management
- [x] Share card generation
- [x] Supabase auth (email/password)
- [x] Cloud sync (summary + optional full route)
- [x] Web dashboard (rides, garage, maintenance)
- [x] Street and Track ride modes
- [x] Ride notes and tags
- [x] Maintenance tracking
- [x] Route privacy (start/end hiding)
- [x] Account deletion
- [x] Local-only mode (no account required)

---

## Next (Near-term)

- [ ] **App Store submission** — prepare metadata, screenshots, privacy policy URL, review guidelines
- [ ] **Apple Sign-In** — required for App Store if other social logins are present
- [ ] **Google Sign-In** — via Supabase provider
- [ ] **Push notifications** — maintenance reminders
- [ ] **Widget** — recent ride stats on home screen / lock screen
- [ ] **Telemetry compression** — gzip JSONL before upload to reduce storage costs
- [ ] **Trim before upload** — permanently strip start/end GPS before cloud upload (irreversible privacy mode)
- [ ] **Custom domain** — pick and configure a domain (see README for options)

---

## Medium-term

- [ ] **Lap timing (basic)** — manual lap splits during track sessions
- [ ] **Advanced track analytics** — corner entry/exit speed, braking zones
- [ ] **Public shared ride pages** — opt-in, share a link with summary stats (no GPS by default)
- [ ] **Export formats** — GPX export from full telemetry, CSV summary export
- [ ] **Web ride editor** — edit notes, tags, bike association from web
- [ ] **Offline map caching** — cache map tiles for offline route viewing
- [ ] **Strava integration** — one-way export of ride summaries

---

## Long-term / Stretch

- [ ] **Leaderboards** — opt-in speed/lean leaderboards by region or track
- [ ] **Social features** — follow riders, see their public ride summaries
- [ ] **Fleet mode** — multiple riders in an organization (track day groups, clubs)
- [ ] **AI ride coach** — LLM-powered insights from telemetry (e.g. "your corner entry speed increased 10% this session")
- [ ] **Android app** — React Native or Flutter port
- [ ] **CarPlay integration** — recording controls on CarPlay display
- [ ] **Apple Watch app** — live stats on wrist

---

## Non-goals (explicitly out of scope)

- Web ride recording (GPS not available in browser)
- Live tracking / sharing location in real-time
- Navigation / turn-by-turn
- Music / media controls
- OBD-II integration (out of scope for v1)
