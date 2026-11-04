import type { Metadata } from "next";
import { Fraunces, Outfit } from "next/font/google";
import { SiteHeader } from "@/components/site-header";
import { currentProfile } from "@/lib/campus";
import "./globals.css";

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-fraunces",
});

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Lost & Found",
  description: "Northbridge College lost and found, on the shared campus record.",
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const profile = await currentProfile();
  return (
    <html className={`${outfit.variable} ${fraunces.variable} h-full`} lang="en">
      <body className="min-h-full antialiased">
        <SiteHeader profile={profile} />
        <main className="mx-auto max-w-6xl px-5 py-8">{children}</main>
      </body>
    </html>
  );
}
