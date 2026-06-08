export interface RideSummaryRow {
  id: string;
  user_id: string;
  name: string | null;
  ride_type: "street" | "track";
  started_at: string | null;
  ended_at: string | null;
  duration_seconds: number;
  distance_meters: number;
  max_speed_mps: number;
  avg_speed_mps: number;
  max_lean_deg: number;
  max_left_lean_deg: number;
  max_right_lean_deg: number;
  elevation_gain_meters: number | null;
  hard_braking_count: number;
  aggressive_accel_count: number;
  notes: string | null;
  tags: string[];
  bike_id: string | null;
  storage_mode: string;
  sync_status: string;
  photo_path: string | null;
  created_at: string;
}

export interface BikeRow {
  id: string;
  user_id: string;
  nickname: string;
  make: string;
  model: string;
  year: number | null;
  notes: string | null;
  odometer_miles: number | null;
  is_default: boolean;
  is_archived: boolean;
  photo_path: string | null;
  created_at: string;
}

export interface MaintenanceRow {
  id: string;
  user_id: string;
  bike_id: string | null;
  type: string;
  title: string;
  date: string;
  odometer_miles: number | null;
  notes: string | null;
  reminder_interval_days: number | null;
  is_archived: boolean;
  created_at: string;
}

// Unit conversion helpers
export const mpsToMph = (mps: number): number => mps * 2.23694;
export const metersToMiles = (m: number): number => m / 1609.344;
export const metersToFeet = (m: number): number => m * 3.28084;
export const secToDisplay = (sec: number): string => {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
};
