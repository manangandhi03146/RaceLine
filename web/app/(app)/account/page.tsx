export const dynamic = "force-dynamic";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import AccountClient from "./AccountClient";

export default async function AccountPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/auth");

  const [{ count: rideCount }, { count: bikeCount }] = await Promise.all([
    supabase.from("rides").select("*", { count: "exact", head: true }),
    supabase.from("bikes").select("*", { count: "exact", head: true }),
  ]);

  return (
    <AccountClient
      email={user.email ?? ""}
      rideCount={rideCount ?? 0}
      bikeCount={bikeCount ?? 0}
    />
  );
}
