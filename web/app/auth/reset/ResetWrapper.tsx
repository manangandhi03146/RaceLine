"use client";

import dynamic from "next/dynamic";

const ResetForm = dynamic(() => import("./ResetForm"), { ssr: false });

export default function ResetWrapper() {
  return <ResetForm />;
}
