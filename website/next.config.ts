import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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
