export const dynamic = "force-dynamic";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import type { BikeRow, RideSummaryRow } from "@/lib/types";
import { mpsToMph, metersToMiles } from "@/lib/types";

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

export default async function GaragePage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/auth");

  const [{ data: bikes }, { data: rides }] = await Promise.all([
    supabase.from("bikes").select("*").order("created_at", { ascending: false }),
    supabase.from("rides").select("id, bike_id, distance_meters, max_speed_mps, max_right_lean_deg, max_left_lean_deg, started_at"),
  ]);

  const bikeList = (bikes ?? []) as BikeRow[];
  const rideList = (rides ?? []) as Pick<RideSummaryRow, "id" | "bike_id" | "distance_meters" | "max_speed_mps" | "max_right_lean_deg" | "max_left_lean_deg" | "started_at">[];

  const activeBikes = bikeList.filter((b) => !b.is_archived);
  const archivedBikes = bikeList.filter((b) => b.is_archived);

  function statsForBike(bikeId: string) {
    const bikeRides = rideList.filter((r) => r.bike_id === bikeId);
    return {
      count: bikeRides.length,
      miles: bikeRides.reduce((s, r) => s + metersToMiles(r.distance_meters), 0),
      topSpeed: bikeRides.reduce((m, r) => Math.max(m, mpsToMph(r.max_speed_mps)), 0),
      maxLean: bikeRides.reduce((m, r) => Math.max(m, r.max_right_lean_deg, r.max_left_lean_deg), 0),
      lastRide: bikeRides.map((r) => r.started_at).sort().at(-1),
    };
  }

  function BikeCard({ bike }: { bike: BikeRow }) {
    const stats = statsForBike(bike.id);
    const title = bike.nickname || `${bike.year ?? ""} ${bike.make} ${bike.model}`.trim();
    return (
      <div className="rounded-xl bg-[var(--surface)] p-5">
        <div className="mb-3 flex items-start gap-3">
          <div className="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl bg-[var(--accent)]/15 text-2xl">
            🏍️
          </div>
          <div>
            <p className="font-semibold text-[var(--text-primary)]">{title}</p>
            {bike.nickname && (
              <p className="text-sm text-[var(--accent)]/80">
                {[bike.year, bike.make, bike.model].filter(Boolean).join(" ")}
              </p>
            )}
            <p className="text-xs text-[var(--text-ghost)]">Added {formatDate(bike.created_at)}</p>
          </div>
          {bike.is_archived && (
            <span className="ml-auto rounded-full bg-[var(--surface2)] px-2.5 py-0.5 text-xs text-[var(--text-ghost)]">
              Archived
            </span>
          )}
        </div>

        {stats.count > 0 ? (
          <div className="grid grid-cols-4 gap-2">
            {[
              { label: "Rides", value: stats.count.toString() },
              { label: "Miles", value: stats.miles.toFixed(0) },
              { label: "Top mph", value: stats.topSpeed.toFixed(0) },
              { label: "Max lean", value: `${stats.maxLean.toFixed(0)}°` },
            ].map((s) => (
              <div key={s.label} className="rounded-lg bg-[var(--surface2)] p-2.5 text-center">
                <p className="text-base font-bold tabular-nums text-[var(--accent)]">{s.value}</p>
                <p className="text-[10px] font-semibold uppercase tracking-wide text-[var(--text-ghost)]">{s.label}</p>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-[var(--text-ghost)] italic">No rides logged with this bike.</p>
        )}

        {bike.notes && (
          <p className="mt-3 text-sm text-[var(--text-secondary)]">{bike.notes}</p>
        )}
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold text-[var(--text-primary)]">Garage</h1>

      {activeBikes.length === 0 && archivedBikes.length === 0 ? (
        <div className="rounded-xl bg-[var(--surface)] p-12 text-center">
          <div className="mb-3 text-4xl">🏍️</div>
          <p className="text-lg font-semibold text-[var(--text-primary)]">No bikes synced</p>
          <p className="mt-1 text-[var(--text-secondary)]">
            Add bikes in the Tread iOS app and enable cloud sync.
          </p>
        </div>
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {activeBikes.map((bike) => <BikeCard key={bike.id} bike={bike} />)}
          </div>

          {archivedBikes.length > 0 && (
            <div className="mt-8">
              <h2 className="mb-3 text-sm font-semibold uppercase tracking-widest text-[var(--text-ghost)]">
                Archived
              </h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {archivedBikes.map((bike) => <BikeCard key={bike.id} bike={bike} />)}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
