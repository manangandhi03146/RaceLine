import Link from "next/link";

const features = [
  {
    icon: "🏍️",
    title: "Street & Track Mode",
    desc: "Separate logging profiles for street rides and track days.",
  },
  {
    icon: "📐",
    title: "Lean Angle Tracking",
    desc: "Real-time left/right lean angles via your phone's gyroscope.",
  },
  {
    icon: "🔒",
    title: "Privacy First",
    desc: "GPS routes stay on your device by default. Cloud sync is opt-in.",
  },
  {
    icon: "🔧",
    title: "Maintenance Log",
    desc: "Track oil changes, tire swaps, and more with reminder notifications.",
  },
  {
    icon: "📊",
    title: "Ride Analytics",
    desc: "Speed, distance, elevation, hard braking events, and more.",
  },
  {
    icon: "🏎️",
    title: "Multi-Bike Garage",
    desc: "Manage your fleet with per-bike stats and service history.",
  },
];

export default function LandingPage() {
  return (
    <div className="flex flex-col min-h-screen">
      {/* Header */}
      <header className="border-b border-[var(--divider)] bg-[var(--surface)]">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-4">
          <span className="text-xl font-bold text-[var(--accent)] tracking-tight">Tread</span>
          <div className="flex items-center gap-4">
            <Link href="/privacy" className="text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)]">
              Privacy
            </Link>
            <Link
              href="/auth"
              className="rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-white hover:bg-[var(--accent)]/90 transition-colors"
            >
              Sign In
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="flex flex-col items-center justify-center px-4 py-24 text-center">
        <div className="mb-6 inline-flex h-20 w-20 items-center justify-center rounded-full bg-[var(--accent)]/15 text-5xl">
          🏍️
        </div>
        <h1 className="mb-4 text-5xl font-bold tracking-tight text-[var(--text-primary)] sm:text-6xl">
          Ride more.<br />
          <span className="text-[var(--accent)]">Track smarter.</span>
        </h1>
        <p className="mb-8 max-w-xl text-lg text-[var(--text-secondary)]">
          Privacy-first motorcycle ride tracking with lean angles, speed, maintenance logs, and optional cloud sync. Your data, your rules.
        </p>
        <div className="flex flex-col items-center gap-3 sm:flex-row">
          <Link
            href="/auth"
            className="rounded-xl bg-[var(--accent)] px-8 py-3.5 text-base font-semibold text-white hover:bg-[var(--accent)]/90 transition-colors"
          >
            Get Started Free
          </Link>
          <Link
            href="/privacy"
            className="rounded-xl border border-[var(--divider)] px-8 py-3.5 text-base font-semibold text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:border-[var(--text-ghost)] transition-colors"
          >
            Privacy Policy
          </Link>
        </div>
      </section>

      {/* Features grid */}
      <section className="mx-auto max-w-6xl px-4 pb-24">
        <h2 className="mb-10 text-center text-2xl font-bold text-[var(--text-primary)]">
          Everything you need on two wheels
        </h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div key={f.title} className="rounded-xl bg-[var(--surface)] p-6">
              <div className="mb-3 text-3xl">{f.icon}</div>
              <h3 className="mb-1.5 font-semibold text-[var(--text-primary)]">{f.title}</h3>
              <p className="text-sm text-[var(--text-secondary)]">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Privacy callout */}
      <section className="border-t border-[var(--divider)] bg-[var(--surface)] px-4 py-16">
        <div className="mx-auto max-w-2xl text-center">
          <div className="mb-4 text-4xl">🔒</div>
          <h2 className="mb-3 text-2xl font-bold text-[var(--text-primary)]">
            Privacy built in, not bolted on
          </h2>
          <p className="mb-6 text-[var(--text-secondary)]">
            Use Tread without an account — rides stay on your phone forever. When you opt in to cloud sync, only summary stats (speed, distance, lean angles) are uploaded by default. Your GPS routes never leave your device unless you explicitly enable full route sync.
          </p>
          <Link href="/privacy" className="text-sm font-semibold text-[var(--accent)] hover:underline">
            Read the full privacy policy →
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-[var(--divider)] px-4 py-8">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-3 sm:flex-row sm:justify-between">
          <span className="text-sm font-bold text-[var(--accent)]">Tread</span>
          <div className="flex gap-6 text-sm text-[var(--text-ghost)]">
            <Link href="/privacy" className="hover:text-[var(--text-secondary)]">Privacy Policy</Link>
            <Link href="/auth" className="hover:text-[var(--text-secondary)]">Sign In</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
