import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RaceLine — Motorcycle Telemetry",
  description: "Record street and track rides with GPS, lean angle, speed, and elevation telemetry. Apple- and Google-secured sync between your iPhone and the web dashboard.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-[var(--bg)] text-[var(--text-primary)]">
        {children}
      </body>
    </html>
  );
}
