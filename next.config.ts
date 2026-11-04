import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import type { NextConfig } from "next";

function campusEnv(): Record<string, string> {
  const file = path.join(process.cwd(), "config", "supabase.dev.json");
  const fromFile = existsSync(file)
    ? (JSON.parse(readFileSync(file, "utf8")) as {
        SUPABASE_URL?: string;
        SUPABASE_PUBLISHABLE_KEY?: string;
      })
    : {};
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || fromFile.SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || fromFile.SUPABASE_PUBLISHABLE_KEY;
  return {
    ...(url ? { NEXT_PUBLIC_SUPABASE_URL: url } : {}),
    ...(key ? { NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key } : {}),
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
