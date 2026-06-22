// RaceLine — Edge Function: delete-account
// Deletes all user data and the auth user record.
// Called from iOS app and web dashboard after user confirms deletion.
//
// Deploy: supabase functions deploy delete-account
// Requires: SUPABASE_SERVICE_ROLE_KEY in function environment

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get user JWT from request
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Create client with user's JWT to identify who is deleting
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = user.id;

    // Create admin client with service role key for privileged operations
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Delete all database rows (cascades handle most of it, but be explicit)
    await adminClient.from("maintenance_records").delete().eq("user_id", userId);
    await adminClient.from("rides").delete().eq("user_id", userId);
    await adminClient.from("bikes").delete().eq("user_id", userId);
    await adminClient.from("deletion_requests").delete().eq("user_id", userId);
    await adminClient.from("profiles").delete().eq("id", userId);

    // 2. Delete storage objects from all buckets
    const buckets = ["ride-photos", "bike-photos", "ride-telemetry", "maintenance-photos"];
    for (const bucket of buckets) {
      const { data: files } = await adminClient.storage
        .from(bucket)
        .list(userId, { limit: 1000 });

      if (files && files.length > 0) {
        // List nested folders recursively (simplified: list top-level then subfolders)
        const allPaths: string[] = [];
        for (const file of files) {
          if (file.id) {
            // It's a file
            allPaths.push(`${userId}/${file.name}`);
          } else {
            // It's a folder — list its contents
            const { data: subFiles } = await adminClient.storage
              .from(bucket)
              .list(`${userId}/${file.name}`, { limit: 1000 });
            if (subFiles) {
              for (const subFile of subFiles) {
                if (subFile.id) {
                  allPaths.push(`${userId}/${file.name}/${subFile.name}`);
                }
              }
            }
          }
        }
        if (allPaths.length > 0) {
          await adminClient.storage.from(bucket).remove(allPaths);
        }
      }
    }

    // 3. Delete the auth user (must be last)
    const { error: deleteAuthError } = await adminClient.auth.admin.deleteUser(userId);
    if (deleteAuthError) {
      console.error("Failed to delete auth user:", deleteAuthError);
      // Log but don't fail — data is already deleted
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("delete-account error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
