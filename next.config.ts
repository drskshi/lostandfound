import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import type { NextConfig } from "next";

function readCampusFile(name: string) {
  const file = path.join(process.cwd(), "config", name);
  if (!existsSync(file)) return {};
  return JSON.parse(readFileSync(file, "utf8")) as {
    SUPABASE_URL?: string;
    SUPABASE_PUBLISHABLE_KEY?: string;
  };
}

function campusEnv(): Record<string, string> {
  const local = readCampusFile("supabase.dev.json");
  const shared = readCampusFile("supabase.client.json");
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || local.SUPABASE_URL || shared.SUPABASE_URL;
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    local.SUPABASE_PUBLISHABLE_KEY ||
    shared.SUPABASE_PUBLISHABLE_KEY;
  const site =
    process.env.NEXT_PUBLIC_SITE_URL ||
    (process.env.VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
      : process.env.VERCEL_URL
        ? `https://${process.env.VERCEL_URL}`
        : "");
  return {
    ...(url ? { NEXT_PUBLIC_SUPABASE_URL: url } : {}),
    ...(key ? { NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key } : {}),
    ...(site ? { NEXT_PUBLIC_SITE_URL: site } : {}),
  };
}

const nextConfig: NextConfig = {
  // Same values as Flutter's config/supabase.dev.json, unless Vercel already set them.
  env: campusEnv(),
  // Auth reads cookies on every campus page, so the routes stay dynamic.
  cacheComponents: false,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
