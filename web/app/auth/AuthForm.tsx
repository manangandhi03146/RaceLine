"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function AuthForm() {
  const router = useRouter();
  const [mode, setMode] = useState<"signin" | "signup" | "forgot">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setMessage(null);

    const supabase = createClient();
    const trimEmail = email.trim();
    const trimPass = password.trim();

    if (mode === "forgot") {
      const { error } = await supabase.auth.resetPasswordForEmail(trimEmail, {
        redirectTo: `${window.location.origin}/auth/reset`,
      });
      if (error) setError(error.message);
      else setMessage("Check your email for a password reset link.");
      setLoading(false);
      return;
    }

    if (mode === "signup") {
      const { error } = await supabase.auth.signUp({ email: trimEmail, password: trimPass });
      if (error) setError(friendlyError(error.message));
      else setMessage("Check your email to confirm your account.");
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email: trimEmail, password: trimPass });
      if (error) setError(friendlyError(error.message));
      else router.push("/dashboard");
    }
    setLoading(false);
  }

  function friendlyError(msg: string): string {
    const m = msg.toLowerCase();
    if (m.includes("invalid login credentials") || m.includes("invalid_credentials"))
      return "Incorrect email or password.";
    if (m.includes("email") && m.includes("already"))
      return "An account with this email already exists.";
    if (m.includes("password") && (m.includes("weak") || m.includes("short")))
      return "Password must be at least 6 characters.";
    if (m.includes("network") || m.includes("offline"))
      return "Network error. Check your connection.";
    return "Something went wrong. Please try again.";
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-4 py-12">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-[var(--accent)]/15 text-4xl">
            🏍️
          </div>
          <h1 className="text-3xl font-bold text-[var(--text-primary)]">Tread</h1>
          <p className="mt-1 text-[var(--text-secondary)]">Privacy-first ride tracking</p>
        </div>

        <div className="rounded-2xl bg-[var(--surface)] p-6">
          {mode !== "forgot" && (
            <div className="mb-4 flex rounded-xl bg-[var(--surface2)] p-1">
              {(["signin", "signup"] as const).map((m) => (
                <button
                  key={m}
                  onClick={() => { setMode(m); setError(null); setMessage(null); }}
                  className={`flex-1 rounded-lg py-2 text-sm font-semibold transition-colors ${
                    mode === m
                      ? "bg-[var(--accent)] text-white"
                      : "text-[var(--text-secondary)] hover:text-[var(--text-primary)]"
                  }`}
                >
                  {m === "signin" ? "Sign In" : "Create Account"}
                </button>
              ))}
            </div>
          )}

          {mode === "forgot" && (
            <div className="mb-4">
              <button onClick={() => { setMode("signin"); setError(null); setMessage(null); }}
                className="text-sm text-[var(--accent)] hover:underline"
              >
                ← Back to sign in
              </button>
              <h2 className="mt-2 text-xl font-bold text-[var(--text-primary)]">Reset Password</h2>
              <p className="mt-1 text-sm text-[var(--text-secondary)]">
                Enter your email and we'll send a reset link.
              </p>
            </div>
          )}

          {message && (
            <div className="mb-4 rounded-xl bg-[var(--accent)]/12 p-3 text-sm text-[var(--text-primary)]">
              {message}
            </div>
          )}

          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="rounded-xl border border-[var(--divider)] bg-[var(--surface2)] px-4 py-3 text-[var(--text-primary)] placeholder-[var(--text-ghost)] focus:border-[var(--accent)] focus:outline-none"
            />
            {mode !== "forgot" && (
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="rounded-xl border border-[var(--divider)] bg-[var(--surface2)] px-4 py-3 text-[var(--text-primary)] placeholder-[var(--text-ghost)] focus:border-[var(--accent)] focus:outline-none"
              />
            )}

            {error && <p className="text-sm text-red-400">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="mt-1 rounded-xl bg-[var(--accent)] py-3.5 text-base font-semibold text-white transition-opacity disabled:opacity-60"
            >
              {loading
                ? "…"
                : mode === "signup"
                  ? "Create Account"
                  : mode === "forgot"
                    ? "Send Reset Link"
                    : "Sign In"}
            </button>
          </form>

          {mode === "signin" && (
            <button
              onClick={() => { setMode("forgot"); setError(null); setMessage(null); }}
              className="mt-3 w-full text-center text-sm text-[var(--accent)] hover:underline"
            >
              Forgot password?
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
