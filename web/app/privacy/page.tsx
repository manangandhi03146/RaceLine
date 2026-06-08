import Link from "next/link";

const sections = [
  {
    title: "What we collect",
    body: `Tread collects only the data you choose to provide: your email address (for account creation), ride stats, and optionally GPS route data if you enable full cloud sync.

By default, GPS routes are stored locally on your device only. Cloud sync uploads summary statistics (speed, distance, lean angles) without your exact GPS route unless you explicitly enable full route sync.`,
  },
  {
    title: "Local-only mode",
    body: `You can use Tread without creating an account. In local-only mode, all data stays on your device and is never transmitted to any server.`,
  },
  {
    title: "Cloud sync",
    body: `If you enable cloud sync, ride summaries are stored in a private Supabase database. Only you can access your data. Full GPS route data is only uploaded if you choose "Cloud Full Data" storage mode with an explicit privacy warning.`,
  },
  {
    title: "Data deletion",
    body: `You can delete your account and all associated data at any time from Profile → Delete Account. This permanently removes all rides, bikes, and media from our servers.`,
  },
  {
    title: "Third parties",
    body: `Tread does not sell or share your data with third parties. We use Supabase for database and authentication services.`,
  },
  {
    title: "Contact",
    body: `For privacy questions, contact us at: privacy@YOUR_DOMAIN.com`,
  },
];

export default function PrivacyPage() {
  return (
    <div className="flex flex-col min-h-screen">
      <header className="border-b border-[var(--divider)] bg-[var(--surface)]">
        <div className="mx-auto flex max-w-4xl items-center gap-4 px-4 py-4">
          <Link href="/" className="text-xl font-bold text-[var(--accent)] tracking-tight">Tread</Link>
        </div>
      </header>

      <main className="mx-auto max-w-4xl px-4 py-12 flex-1">
        <h1 className="mb-2 text-3xl font-bold text-[var(--text-primary)]">Privacy Policy</h1>
        <p className="mb-8 text-sm text-[var(--text-secondary)]">Last updated: June 2026</p>

        <div className="flex flex-col gap-4">
          {sections.map((s) => (
            <div key={s.title} className="rounded-xl bg-[var(--surface)] p-5">
              <h2 className="mb-2 font-semibold text-[var(--text-primary)]">{s.title}</h2>
              <p className="whitespace-pre-wrap text-sm text-[var(--text-secondary)] leading-relaxed">{s.body}</p>
            </div>
          ))}
        </div>
      </main>

      <footer className="border-t border-[var(--divider)] px-4 py-6">
        <div className="mx-auto max-w-4xl text-center">
          <Link href="/" className="text-sm text-[var(--text-ghost)] hover:text-[var(--text-secondary)]">
            ← Back to Tread
          </Link>
        </div>
      </footer>
    </div>
  );
}
