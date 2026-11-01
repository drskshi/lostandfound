# Flutter Web on your own Vercel project

Do not import the previous owner's GitHub repository. Do not change the live React site.

`web/vercel.json` is copied into the web build. It sends every path back to `index.html`, so a refresh on `/login` still opens the app.

## Deploy the built site

1. Create a new, empty Vercel project under your own account.
2. From this folder, build:

```sh
flutter build web --release --dart-define-from-file=config/supabase.dev.json
```

The publishable key is compiled into that build. The service-role key is not.

3. Deploy only the folder `build/web` to the new Vercel project. The Vercel dashboard can do this as a static upload, or the Vercel CLI can deploy that folder after you approve the link to your account.
4. After the site has an address, add that address to Supabase redirect URLs, for example `https://your-new-site.vercel.app/**`.
5. Run the site with `--web-port 3000` only for local Google tests. Production uses the Vercel address.

## Updating later

Build again with the same command, then deploy `build/web` again. The previous React deployment stays where it is.

## Current result

A production upload to Vercel was not performed. Direct-link behaviour on a hosted domain is NOT TESTED.
