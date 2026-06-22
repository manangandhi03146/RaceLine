export const dynamic = "force-dynamic";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import Link from "next/link";
import StatCard from "@/components/ui/StatCard";
import type { RideSummaryRow, BikeRow } from "@/lib/types";
import { mpsToMph, metersToMiles, secToDisplay } from "@/lib/types";
import { LocalDate } from "@/components/LocalDate";

const DASHBOARD_DATE_OPTS: Intl.DateTimeFormatOptions = {
  month: "short", day: "numeric", year: "numeric",
};

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/auth");

  const [{ data: rides }, { data: bikes }] = await Promise.all([
    supabase.from("rides").select("*").order("started_at", { ascending: false }).limit(200),
    supabase.from("bikes").select("*").eq("is_archived", false),
  ]);

  const rideList = (rides ?? []) as RideSummaryRow[];
  const bikeList = (bikes ?? []) as BikeRow[];

  const totalMiles = rideList.reduce((sum, r) => sum + metersToMiles(r.distance_meters), 0);
  const maxSpeedMph = rideList.reduce((max, r) => Math.max(max, mpsToMph(r.max_speed_mps)), 0);
  const maxLean = rideList.reduce((max, r) => Math.max(max, r.max_right_lean_deg, r.max_left_lean_deg), 0);
  const recentRides = rideList.slice(0, 5);

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold text-[var(--text-primary)]">Dashboard</h1>

      {/* Stats row */}
      <div className="mb-8 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="Total Rides" value={rideList.length} accent />
        <StatCard label="Total Miles" value={totalMiles.toFixed(0)} sub="miles" />
        <StatCard label="Top Speed" value={maxSpeedMph.toFixed(0)} sub="mph" />
        <StatCard label="Max Lean" value={`${maxLean.toFixed(0)}°`} sub="degrees" />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Recent rides */}
        <div className="lg:col-span-2">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-semibold text-[var(--text-primary)]">Recent Rides</h2>
            <Link href="/rides" className="text-sm text-[var(--accent)] hover:underline">
              View all
            </Link>
          </div>
          <div className="flex flex-col gap-2">
            {recentRides.length === 0 ? (
              <div className="rounded-xl bg-[var(--surface)] p-8 text-center text-[var(--text-secondary)]">
                No rides synced yet. Record a ride in the Tread iOS app.
              </div>
            ) : (
              recentRides.map((ride) => (
                <Link key={ride.id} href={`/rides/${ride.id}`}>
                  <div className="flex items-center gap-4 rounded-xl bg-[var(--surface)] p-4 hover:bg-[var(--surface2)] transition-colors">
                    <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-[var(--accent)]/15 text-lg">
                      {ride.ride_type === "track" ? "🏁" : "🛣️"}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-[var(--text-primary)] truncate">
                        {ride.name ?? "Unnamed Ride"}
                      </p>
                      <p className="text-sm text-[var(--text-secondary)]">
                        {ride.started_at ? <LocalDate iso={ride.started_at} options={DASHBOARD_DATE_OPTS} /> : "—"} · {metersToMiles(ride.distance_meters).toFixed(1)} mi · {secToDisplay(ride.duration_seconds)}
                      </p>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className="text-sm font-semibold text-[var(--accent)]">{mpsToMph(ride.max_speed_mps).toFixed(0)} mph</p>
                      <p className="text-xs text-[var(--text-ghost)]">{Math.max(ride.max_right_lean_deg, ride.max_left_lean_deg).toFixed(0)}° lean</p>
                    </div>
                  </div>
                </Link>
              ))
            )}
          </div>
        </div>

        {/* Garage sidebar */}
        <div>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="font-semibold text-[var(--text-primary)]">Garage</h2>
            <Link href="/garage" className="text-sm text-[var(--accent)] hover:underline">
              View all
            </Link>
          </div>
          <div className="flex flex-col gap-2">
            {bikeList.length === 0 ? (
              <div className="rounded-xl bg-[var(--surface)] p-6 text-center text-sm text-[var(--text-secondary)]">
                No bikes synced yet.
              </div>
            ) : (
              bikeList.map((bike) => {
                const bikeRides = rideList.filter((r) => r.bike_id === bike.id);
                const bikeMiles = bikeRides.reduce((s, r) => s + metersToMiles(r.distance_meters), 0);
                return (
                  <div key={bike.id} className="rounded-xl bg-[var(--surface)] p-4">
                    <p className="font-semibold text-[var(--text-primary)]">
                      {bike.nickname || `${bike.year ?? ""} ${bike.make} ${bike.model}`.trim()}
                    </p>
                    <p className="text-sm text-[var(--accent)]/80">{bike.year} {bike.make} {bike.model}</p>
                    <p className="mt-1 text-xs text-[var(--text-secondary)]">
                      {bikeRides.length} ride{bikeRides.length !== 1 ? "s" : ""} · {bikeMiles.toFixed(0)} mi
                    </p>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
