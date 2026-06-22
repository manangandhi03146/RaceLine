"use client";

import { useEffect, useState } from "react";

interface Props {
  iso: string;
  /** Formatter options. Defaults to a long "Mon, June 22, 2026 at 2:06 AM" style. */
  options?: Intl.DateTimeFormatOptions;
  /** Shown until client-side hydration replaces it (prevents SSR/UTC mismatch flash). */
  fallback?: string;
}

const DEFAULT_OPTIONS: Intl.DateTimeFormatOptions = {
  weekday: "short",
  month: "long",
  day: "numeric",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
};

/**
 * Renders an ISO timestamp in the *browser's* local timezone.
 *
 * Server components render dates in Vercel's UTC timezone, which made every ride
 * page show a UTC time labelled as if it were local. Doing the format inside a
 * client effect ensures the user sees their own wall-clock time.
 */
export function LocalDate({ iso, options, fallback = "" }: Props) {
  const [formatted, setFormatted] = useState<string | null>(null);

  useEffect(() => {
    if (!iso) return;
    setFormatted(new Date(iso).toLocaleString(undefined, options ?? DEFAULT_OPTIONS));
  }, [iso, options]);

  return (
    <time dateTime={iso} suppressHydrationWarning>
      {formatted ?? fallback}
    </time>
  );
}
