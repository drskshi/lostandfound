# Lost & Found website

Independent Next.js site for Northbridge College. It uses the existing Supabase project `iuitbmbovoroffkwwlfk`. It does not create tables, and it does not contain the Flutter app.

## Run locally

Copy `.env.example` to `.env.local` and set `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to the publishable key. Do not put a service-role key, SMTP password, or Google client secret in this project.

```sh
npm install
npm run dev
```

## Vercel

Use this folder as its own project.

- Framework Preset: Next.js
- Root Directory: the folder that contains this `package.json`
- Build Command: `next build`
- Environment variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and `NEXT_PUBLIC_SITE_URL` set to the live https address

After the site has a public address, add `https://that-address/**` to the Supabase Auth redirect allow list.
