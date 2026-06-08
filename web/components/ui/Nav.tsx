"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/rides", label: "Rides" },
  { href: "/garage", label: "Garage" },
  { href: "/maintenance", label: "Maintenance" },
];

export default function Nav() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-50 border-b border-[var(--divider)] bg-[var(--surface)]">
      <div className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3">
        <Link href="/dashboard" className="font-bold text-[var(--accent)] text-lg tracking-tight">
          Tread
        </Link>
        <div className="flex items-center gap-1 flex-1">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                pathname.startsWith(l.href)
                  ? "bg-[var(--accent)]/15 text-[var(--accent)]"
                  : "text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface2)]"
              }`}
            >
              {l.label}
            </Link>
          ))}
        </div>
        <Link
          href="/account"
          className="text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
        >
          Account
        </Link>
      </div>
    </nav>
  );
}
