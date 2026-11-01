# Multiplatform feature parity

Date: 1 November 2026.

Flutter Web did not exist before this pass. The project had Android and iOS runners only. A web runner was added to this same project. The live React site on Vercel was not changed.

Switching the live website from React to Flutter is not justified yet. The Flutter UI still keeps posts on the device. The React source has the fuller office, and the live site is a separate browser demo. A successful `flutter build web` only compiles the current phone UI.

## What each codebase is

| System | What it is today |
| --- | --- |
| React source in `uni-lost-and-found` | Next.js app. Accounts, posts, and claims use SQLite. This server is not what Vercel publishes. |
| Live Vercel site | Built with `npm run build:demo` into `demo-dist`. State stays in the browser. |
| Flutter `lost_found_mobile` | One app for Android, iOS, and now Web. Records stay in on-device storage unless a later cutover reads Supabase. |

## Feature comparison

| Journey | React source | Live demo | Flutter on Android, iOS, and Web |
| --- | --- | --- | --- |
| Landing and demo entry | Present | Present | Splash and onboarding |
| Register, sign in, verify, privacy | Present, server session | Present in the browser demo | Present on the local store |
| Google sign-in | Not connected | Not connected | Button shows a notice. No OAuth client |
| Email delivery | Logs only, or stops if a provider name is set | Not connected | Not connected |
| Feed, search, map | Present | Present | Present, with paging on feed and search |
| Create a post and open it | Present | Present | Present |
| Photos | Files on the server disk | Browser only | Device picker. No shared image cache |
| Save a post | Present | Present | Present on this device |
| Submit and track a claim | Present | Present | Present on this device |
| Staff review, inventory, reports, members, audit | Present for STAFF and ADMIN | Client-side role switch | Present for the local staff and admin demo |
| Superadmin, Admin, Sub-admin, Student offices | Route exists and stays closed for MEMBER, STAFF, and ADMIN | Not the database roles | Short dashboards. They do not grant access |
| Institution and department isolation | SQLite scopes a user to one university | Not server isolation | Local demo filters by campus. Database rules exist in Supabase and are not what the screens read |
| Shared production records | SQLite, one machine | Browser memory | Device storage. Supabase is optional startup only |
| Desktop, tablet, and phone layouts | React pages | React demo | Phone navigation. No desktop or tablet layout |
| Accessibility pages | Present | Present | Material controls. No separate accessibility page |

## Platform support

| Platform | Project files | Ready for production |
| --- | --- | --- |
| Android | `android/` | Demo app builds. Production records are not shared |
| iOS | `ios/` | Demo app builds. Production records are not shared |
| Web | `web/` added in this pass | Compiles the same demo. Not a replacement for the React site |
