import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Tread — Privacy-First Ride Tracking",
  description: "Track motorcycle rides with privacy-first cloud sync. Street mode, track mode, lean angles, speed, and more.",
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
