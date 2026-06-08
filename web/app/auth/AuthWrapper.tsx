"use client";

import dynamic from "next/dynamic";

const AuthForm = dynamic(() => import("./AuthForm"), { ssr: false });

export default function AuthWrapper() {
  return <AuthForm />;
}
