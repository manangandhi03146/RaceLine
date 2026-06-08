"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

interface Props {
  email: string;
  rideCount: number;
  bikeCount: number;
}

export default function AccountClient({ email, rideCount, bikeCount }: Props) {
  const router = useRouter();
  const supabase = createClient();
  const [signingOut, setSigningOut] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signOut() {
    setSigningOut(true);
    await supabase.auth.signOut();
    router.push("/");
  }

  async function deleteAccount() {
    setDeleting(true);
    setError(null);
    try {
      const { error } = await supabase.functions.invoke("delete-account");
      if (error) throw error;
      await supabase.auth.signOut();
      router.push("/");
    } catch {
      setError("Could not delete account. Please try again or contact support.");
    }
    setDeleting(false);
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold text-[var(--text-primary)]">Account</h1>

      {/* Profile card */}
      <div className="mb-4 rounded-xl bg-[var(--surface)] p-6">
        <div className="flex items-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[var(--accent)]/15 text-2xl font-bold text-[var(--accent)]">
            {email.charAt(0).toUpperCase()}
          </div>
          <div>
            <p className="font-semibold text-[var(--text-primary)]">{email}</p>
            <p className="text-sm text-[var(--text-secondary)]">
              {rideCount} ride{rideCount !== 1 ? "s" : ""} · {bikeCount} bike{bikeCount !== 1 ? "s" : ""} synced
            </p>
          </div>
        </div>
      </div>

      {/* Links */}
      <div className="mb-4 rounded-xl bg-[var(--surface)] overflow-hidden">
        <Link href="/privacy" className="flex items-center justify-between px-5 py-4 hover:bg-[var(--surface2)] transition-colors border-b border-[var(--divider)]">
          <span className="text-sm text-[var(--text-primary)]">Privacy Policy</span>
          <span className="text-[var(--text-ghost)]">→</span>
        </Link>
        <div className="flex items-center justify-between px-5 py-4">
          <span className="text-sm text-[var(--text-secondary)]">Cloud Sync</span>
          <span className="rounded-full bg-green-500/15 px-2.5 py-0.5 text-xs font-semibold text-green-400">Active</span>
        </div>
      </div>

      {error && (
        <div className="mb-4 rounded-xl bg-red-500/10 px-4 py-3 text-sm text-red-400">{error}</div>
      )}

      {/* Sign out */}
      <button
        onClick={signOut}
        disabled={signingOut}
        className="w-full rounded-xl bg-[var(--surface2)] py-3.5 font-semibold text-[var(--text-primary)] hover:bg-[var(--surface)] transition-colors disabled:opacity-60 mb-3"
      >
        {signingOut ? "Signing out…" : "Sign Out"}
      </button>

      {/* Delete account */}
      {!showDeleteConfirm ? (
        <button
          onClick={() => setShowDeleteConfirm(true)}
          className="w-full rounded-xl py-3.5 text-sm font-semibold text-red-400 hover:bg-red-500/10 transition-colors"
        >
          Delete Account
        </button>
      ) : (
        <div className="rounded-xl border border-red-500/30 bg-red-500/8 p-5">
          <p className="mb-2 font-semibold text-red-300">Delete your account?</p>
          <p className="mb-4 text-sm text-red-300/70">
            This permanently deletes all your rides, bikes, and account data. This cannot be undone.
          </p>
          <div className="flex gap-3">
            <button
              onClick={() => setShowDeleteConfirm(false)}
              className="flex-1 rounded-xl border border-[var(--divider)] py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={deleteAccount}
              disabled={deleting}
              className="flex-1 rounded-xl bg-red-600 py-2.5 text-sm font-semibold text-white hover:bg-red-700 transition-colors disabled:opacity-60"
            >
              {deleting ? "Deleting…" : "Yes, Delete Everything"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
