export const dynamic = "force-dynamic";

import { createClient } from "@/lib/supabase/server";
import { redirect, notFound } from "next/navigation";
import Link from "next/link";
import type { RideSummaryRow, BikeRow } from "@/lib/types";
import { mpsToMph, metersToMiles, metersToFeet } from "@/lib/types";

function formatDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    weekday: "short", month: "long", day: "numeric", year: "numeric",
    hour: "numeric", minute: "2-digit",
  });
}

interface StatRowProps { label: string; value: string }
function StatRow({ label, value }: StatRowProps) {
  return (
    <div className="flex items-center justify-between py-2.5 border-b border-[var(--divider)] last:border-0">
      <span className="text-sm text-[var(--text-secondary)]">{label}</span>
      <span className="text-sm font-semibold text-[var(--text-primary)] tabular-nums">{value}</span>
    </div>
  );
}

export default async function RideDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/auth");

  const { data: rideData } = await supabase.from("rides").select("*").eq("id", id).single();
  if (!rideData) notFound();
  const ride = rideData as RideSummaryRow;

  let bike: BikeRow | null = null;
  if (ride.bike_id) {
    const { data } = await supabase.from("bikes").select("*").eq("id", ride.bike_id).single();
    bike = data as BikeRow | null;
  }

  const distanceMi = metersToMiles(ride.distance_meters);
  const maxSpeedMph = mpsToMph(ride.max_speed_mps);
  const avgSpeedMph = mpsToMph(ride.avg_speed_mps);
  const maxLean = Math.max(ride.max_right_lean_deg, ride.max_left_lean_deg);

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <Link href="/rides" className="mb-4 inline-flex items-center gap-1 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)]">
        ← All Rides
      </Link>

      {/* Header */}
      <div className="mb-6 flex items-start gap-4">
        <div className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl bg-[var(--accent)]/15 text-3xl">
          {ride.ride_type === "track" ? "🏁" : "🛣️"}
        </div>
        <div>
          <h1 className="text-2xl font-bold text-[var(--text-primary)]">
            {ride.name ?? "Unnamed Ride"}
          </h1>
          <p className="text-[var(--text-secondary)]">
            {ride.started_at ? formatDate(ride.started_at) : "—"}
          </p>
          {bike && (
            <p className="mt-0.5 text-sm text-[var(--accent)]/80">
              {bike.nickname || `${bike.year ?? ""} ${bike.make} ${bike.model}`.trim()}
            </p>
          )}
        </div>
      </div>

      {/* Tags */}
      {ride.tags && ride.tags.length > 0 && (
        <div className="mb-4 flex flex-wrap gap-2">
          {ride.tags.map((tag) => (
            <span key={tag} className="rounded-full bg-[var(--surface2)] px-3 py-1 text-xs text-[var(--text-secondary)]">
              {tag}
            </span>
          ))}
        </div>
      )}

      {/* Stats grid */}
      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          { label: "Distance", value: `${distanceMi.toFixed(2)} mi` },
          { label: "Duration", value: formatDuration(ride.duration_seconds) },
          { label: "Max Speed", value: `${maxSpeedMph.toFixed(0)} mph` },
          { label: "Max Lean", value: `${maxLean.toFixed(1)}°` },
        ].map((s) => (
          <div key={s.label} className="rounded-xl bg-[var(--surface)] p-4">
            <p className="text-xs font-semibold uppercase tracking-widest text-[var(--text-ghost)]">{s.label}</p>
            <p className="mt-1 text-2xl font-bold tabular-nums text-[var(--accent)]">{s.value}</p>
          </div>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Detailed stats */}
        <div className="rounded-xl bg-[var(--surface)] p-5">
          <h2 className="mb-3 font-semibold text-[var(--text-primary)]">Ride Stats</h2>
          <StatRow label="Avg Speed" value={avgSpeedMph > 0 ? `${avgSpeedMph.toFixed(1)} mph` : "—"} />
          <StatRow label="Max Lean Right" value={`${ride.max_right_lean_deg.toFixed(1)}°`} />
          <StatRow label="Max Lean Left" value={`${ride.max_left_lean_deg.toFixed(1)}°`} />
          {ride.elevation_gain_meters != null && (
            <StatRow label="Elevation Gain" value={`${metersToFeet(ride.elevation_gain_meters).toFixed(0)} ft`} />
          )}
          {ride.hard_braking_count > 0 && (
            <StatRow label="Hard Braking Events" value={ride.hard_braking_count.toString()} />
          )}
          {ride.aggressive_accel_count > 0 && (
            <StatRow label="Hard Accel Events" value={ride.aggressive_accel_count.toString()} />
          )}
          <StatRow label="Mode" value={ride.ride_type === "track" ? "Track" : "Street"} />
        </div>

        {/* Notes */}
        <div className="rounded-xl bg-[var(--surface)] p-5">
          <h2 className="mb-3 font-semibold text-[var(--text-primary)]">Notes</h2>
          {ride.notes ? (
            <p className="text-sm text-[var(--text-secondary)] leading-relaxed whitespace-pre-wrap">
              {ride.notes}
            </p>
          ) : (
            <p className="text-sm text-[var(--text-ghost)] italic">No notes for this ride.</p>
          )}

          {(ride.storage_mode === "cloudFull" || ride.storage_mode === "localAndCloudFull") ? (
            <div className="mt-4 rounded-lg bg-[var(--surface2)] px-3 py-2 text-xs text-[var(--text-secondary)]">
              GPS route data available (full telemetry synced)
            </div>
          ) : (
            <div className="mt-4 rounded-lg bg-[var(--surface2)] px-3 py-2 text-xs text-[var(--text-ghost)]">
              Route stored on device only
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
