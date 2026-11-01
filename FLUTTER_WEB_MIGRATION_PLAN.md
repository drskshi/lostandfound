# Flutter Web migration plan

Date: 1 November 2026.

## Decision

Keep the React site as the live website. Do not point Vercel at Flutter until the journeys match, the tests pass, and you approve the cutover.

Flutter Web is suitable later as a third build of this same app, after the app reads and writes Supabase. It is not suitable as a drop-in replacement today.

## Done in this pass

- Added the web runner to `lost_found_mobile` with `flutter create --platforms=web .`
- Restored Android and iOS in `.metadata` after that command kept only the web entry
- Named the web shell Lost & Found and allowed any screen orientation
- Left the React source and `vercel.json` as they were

Removing `web/` reverses the runner. The Android and iOS apps do not depend on it.

## Not started

- Desktop, tablet, and phone layouts for the website journeys
- Replacing on-device posts with Supabase reads and writes
- Loading the four role offices from `role_assignments`
- Image caching and lazy image lists for shared photos
- Google sign-in
- Email delivery

## Later phases, after approval

1. Read and write posts, claims, and profiles through Supabase with the publishable key only. Keep the service-role key on the server.
2. Build the student, department, institution, and platform screens from the database role. The phone layout remains the narrow layout. Wider windows get a side navigation rail.
3. Compare each React journey against the Flutter web build before any DNS or Vercel change.
4. Leave `vercel.json` on `npm run build:demo` until you approve a replacement host for Flutter Web.

## Google and email

Google OAuth and SMTP belong in Supabase Auth and a server or edge function. The Flutter and React clients may start the hosted sign-in flow. They must not contain a client secret, SMTP password, database password, or service-role key.

The current Google button only tells the person that Google sign-in is not connected. The website email module logs the message, or refuses to send when `EMAIL_PROVIDER` is set, because no provider is implemented.
