interface StatCardProps {
  label: string;
  value: string | number;
  sub?: string;
  accent?: boolean;
}

export default function StatCard({ label, value, sub, accent }: StatCardProps) {
  return (
    <div className="rounded-xl bg-[var(--surface)] p-4">
      <p className="text-xs font-semibold uppercase tracking-widest text-[var(--text-ghost)]">{label}</p>
      <p className={`mt-1 text-3xl font-bold tabular-nums ${accent ? "text-[var(--accent)]" : "text-[var(--text-primary)]"}`}>
        {value}
      </p>
      {sub && <p className="mt-0.5 text-xs text-[var(--text-secondary)]">{sub}</p>}
    </div>
  );
}
