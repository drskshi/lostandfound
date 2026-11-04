# Lost & Found website

The Next.js site is the repository root: `package.json`, `src/`, and `vercel.json`. Vercel builds only that website. Flutter for Android and iOS stays in `lib`, `android`, and `ios`. Both use the existing Supabase project `iuitbmbovoroffkwwlfk`.

## Run locally

From the repository root, copy `.env.example` to `.env.local` and set `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to the publishable key. Do not put a service-role key, SMTP password, or Google client secret in this project.

```sh
npm install
npm run dev
```

## Vercel

`vercel.json` sets the framework to Next.js and clears a static output folder such as `build/web`.

- Framework Preset: Next.js
- Root Directory: the repository root, where `package.json` is
- Output Directory: leave this empty
- Environment variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and `NEXT_PUBLIC_SITE_URL` set to the live https address

After the site has a public address, add `https://that-address/**` to the Supabase Auth redirect allow list.
