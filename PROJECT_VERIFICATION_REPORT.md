# Project verification report

Date: 1 November 2026. Evidence is from the files and commands below. No production deployment was changed. No migration was run during this audit.

## 1. Actual current architecture

There are three separate pieces. They do not share one running backend.

1. **Live website.** Vercel builds the Vite demo, not the Next.js server. `uni-lost-and-found/vercel.json` sets `buildCommand` to `npm run build:demo` and `outputDirectory` to `demo-dist`. That demo keeps campus state in the browser (`src/lib/campus-demo.ts`). The sign-in screen can choose `student` or `admin` in the client (`campus-demo.ts` login action). That is not server-side authorisation.

2. **Next.js website source.** `uni-lost-and-found` is a Next.js 16 and React 19 app (`package.json`). Its real data path is Prisma plus a SQLite file (`src/lib/db.ts`). Sessions, claims, and photos are implemented there. This path is not what `vercel.json` publishes.

3. **Flutter phone app.** `lost_found_mobile` is a native Flutter app. Screens call `CampusStore`, which saves data with `shared_preferences` (`lib/data/store.dart`). Supabase is initialised only when compile-time keys are present (`lib/backend/supabase_bootstrap.dart`). No screen queries Supabase. There is no `.from(` call under `lib/`.

4. **Supabase project.** Project host `iuitbmbovoroffkwwlfk.supabase.co` has the Lost & Found tables. Checked on 1 November 2026: `GET /auth/v1/health` returned 200. `GET /rest/v1/items?select=id` with the publishable key and no user session returned 401. A missing table name returned 404, so `items` exists and the anonymous role is denied. No signed-in read or write was run. No test account was available.

## 2. Frameworks

| Piece | Framework | Proof |
| --- | --- | --- |
| Live site | Vite + React demo | `vercel.json`, `package.json` script `build:demo`, `src/lib/campus-demo.ts` |
| Website source | Next.js, React, Prisma, SQLite | `package.json`, `src/lib/db.ts` |
| Phone | Flutter, Dart, Material 3 | `pubspec.yaml`, `lib/main.dart` |
| Cloud database | Supabase Postgres | `backend/migrations/002_lost_found_supabase.sql` and the live REST check above |

Flutter Web has not been created. There is no `lost_found_mobile/web/` directory. `.metadata` lists only `android` and `ios`.

`android/` and `ios/` are present.

The website and the phone do not share a Flutter codebase. The phone screens were written in Dart from the website's behaviour. The React files were not moved into Flutter.

`src/lib/data-source.ts` can return `supabase` only if `DATA_SOURCE=supabase`. Nothing imports that file. The website still opens SQLite.

## 3. Platform build status

| Check | Result |
| --- | --- |
| `flutter analyze` | **PASS.** No issues found. |
| `flutter test` | **FAIL.** 9 passed, 1 failed. `test/widget_test.dart` expected the text `Sign in` and found no widget with that text. |
| `flutter build apk --debug` | **PASS.** `build/app/outputs/flutter-apk/app-debug.apk`. This build did not pass `--dart-define-from-file`, so `Supabase.initialize` does not run in that APK. |
| `flutter build ios --simulator` | **PASS.** `build/ios/iphonesimulator/Runner.app`. Same limitation: no Supabase keys were compiled in. |
| Flutter web build | **NOT TESTED.** `web/` does not exist, so a web build was not started. |

Website `npm test` was run. It **FAILED** to start: `vitest: command not found`. `node_modules` is not installed. `tsc --noEmit` was **NOT TESTED** for the same reason.

## 4. Supabase connection status

| Milestone | Status |
| --- | --- |
| SDK installed | **Yes.** `supabase_flutter` 2.18.3 in `pubspec.yaml`. |
| Initialisation code | **Yes, conditional.** `lib/main.dart` calls `SupabaseBootstrap.start()`. It returns immediately when `SUPABASE_URL` and the publishable key are absent (`lib/backend/backend_config.dart`). |
| App actually initialised | **No** for a normal run and for the APK and simulator builds above. Keys live only in gitignored `config/supabase.dev.json`. They are not compiled in unless the app is launched with `--dart-define-from-file`. |
| Migration file | **Yes.** `backend/migrations/002_lost_found_supabase.sql`. |
| Live schema | **Yes.** Anonymous access to `items` is denied (401), while an unknown table is missing (404). |
| Live connection from the phone | **Not verified.** The running app does not call the database. |
| Authorised read | **NOT TESTED.** No test user was used. |
| Authorised write | **NOT TESTED.** |
| Data still there after restart | **NOT TESTED** for Supabase. The phone store reloads `shared_preferences`. |
| Phone and website seeing the same row | **Not implemented.** |

## 5. Feature status

| Feature | Flutter phone | Next.js source | Live Vercel demo |
| --- | --- | --- | --- |
| Login | DEMO-ONLY. Local accounts in `CampusStore`. | IMPLEMENTED for SQLite sessions (`src/lib/auth.ts`). Not used by the live deploy. | DEMO-ONLY. Client role pick in `campus-demo.ts`. |
| Google OAuth | NOT IMPLEMENTED. Button calls `showGoogleNotice` in `lib/widgets/common.dart`. | NOT IMPLEMENTED. Password sessions only. | NOT IMPLEMENTED. |
| Profiles | DEMO-ONLY. On phone. | IMPLEMENTED in SQLite `User`. | DEMO-ONLY. |
| Campus feed | DEMO-ONLY. | IMPLEMENTED against SQLite. | DEMO-ONLY. |
| Create post | DEMO-ONLY. Saved on the phone. | IMPLEMENTED in server actions. | DEMO-ONLY. Lost on refresh of a new browser profile. |
| Photo upload | DEMO-ONLY. Local file path. | IMPLEMENTED to local disk (`src/lib/storage.ts`). | DEMO-ONLY. |
| Search | DEMO-ONLY. | IMPLEMENTED against SQLite. | DEMO-ONLY. |
| Map | DEMO-ONLY. Painted campus, not a shared map. | IMPLEMENTED with Leaflet in the Next app. | DEMO-ONLY. |
| Saved posts | DEMO-ONLY. | IMPLEMENTED as `Watch` in SQLite. | DEMO-ONLY. |
| Ownership claims | DEMO-ONLY. | IMPLEMENTED in `src/app/actions/claims.ts`. | DEMO-ONLY. |
| Private claim evidence | DEMO-ONLY. Local file. | IMPLEMENTED as a local proof file. | DEMO-ONLY. |
| Staff review | DEMO-ONLY. `isStaff` is a field on the local account. | IMPLEMENTED. `requireStaff()` in `src/lib/auth.ts`. | DEMO-ONLY. The client sets `admin`. |
| Approve and reject | DEMO-ONLY on phone. | IMPLEMENTED in `claims.ts`. | DEMO-ONLY. |
| Collection code | DEMO-ONLY on phone. | IMPLEMENTED. The SQLite column stores the code itself (`handoverCode`). | DEMO-ONLY. |
| Handover | DEMO-ONLY on phone. | IMPLEMENTED in `claims.ts`. | DEMO-ONLY. |
| Audit history | DEMO-ONLY on phone. | IMPLEMENTED as `AuditLog`. | DEMO-ONLY. |
| Email | NOT IMPLEMENTED. Settings say SMTP is not connected. | NOT IMPLEMENTED. `src/lib/email.ts` logs the message, or throws if a provider name is set. | NOT IMPLEMENTED. |

Supabase has tables and two database functions, `approve_claim` and `redeem_collection_code`. No app calls them. That is schema only, not a working feature.

## 6. Role-based security

The four requested roles do not exist.

| Place | Roles found | Server enforced |
| --- | --- | --- |
| Flutter `lib/data/models.dart` | `member`, `staff`, `admin` | No. Checked only inside the phone store. |
| Next.js `src/lib/auth.ts` | `MEMBER`, `STAFF`, `ADMIN` | Yes, for the SQLite app, through `requireStaff` and `requireAdmin`. |
| Live demo `campus-demo.ts` | `student`, `admin` | No. Chosen in the browser. |
| Supabase `profiles.role` | `member`, `staff`, `admin` | The check constraint and Row Level Security exist. No signed-in policy test was run. |

There is no `SUPERADMIN` and no `SUB-ADMIN`. There is no department-scoped permission. A new Supabase account is inserted as `member` by `private.handle_new_user()`.

## 7. Google OAuth

**Not implemented and not tested** on Web, Android, or iOS.

The phone has a button and a dialog that says Google is not connected. There is no Google Sign-In package, no OAuth client ID, no Android SHA fingerprint in the repo, no iOS URL scheme for Google, and no Supabase `signInWithOAuth` call. Session restore and sign-out exist only for the local phone store and, separately, for the Next.js cookie session.

## 8. Website and mobile synchronisation

**Not synchronised.**

- The live site does not use Supabase or the phone store.
- The Next.js app uses SQLite and does not import `src/lib/data-source.ts`.
- The phone uses `shared_preferences`.
- Supabase is a third store. It has schema and denies anonymous reads. It has no proven app writes.

Before they can match, all three must stop being the system of record. One Supabase project must own accounts, posts, photos, and claims. The phone must query it. The website must query it. The live Vercel build must stop publishing only the Vite demo, and that cutover needs approval.

## 9. Remaining work

- Connect Flutter screens to Supabase Auth and the tables, including loading and error states.
- Prove a signed-in read and write, then restart the app and see the same row.
- Add the four roles in the database and enforce them in Row Level Security, not in the client.
- Add department scope for a sub-admin.
- Configure Google on Supabase, Android, and iOS, then test it on devices.
- Send mail from a server function. Do not put an SMTP password in Flutter or React.
- Point the website at the same project only after approval. Do not replace the live deploy until then.
- Fix the failing widget test.
- Install website dependencies and run `npm test` and `tsc --noEmit`.
- Add Flutter `web/` only if a Flutter website is chosen. It is not required for Android and iOS.

## 10. Recommended plan

Keep the React website and the Flutter phone apps. Do not rebuild the site as Flutter Web yet.

The Next.js source already has sessions, claim review, collection, and staff checks. The live site is a separate Vite demo. Replacing both with Flutter Web would mean rewriting those server actions and the deployed demo. Flutter Web can match the look later, but it does not preserve the working server code by itself.

Use one Supabase database for both clients:

1. Keep Android and iOS on the current Flutter app and switch `CampusStore` reads and writes to Supabase.
2. Keep the Next.js app as the website. Add a Supabase adapter beside SQLite, still behind `DATA_SOURCE`, and leave production on the current demo until you approve a cutover.
3. Add `superadmin`, `admin`, `subadmin`, and `student` in Postgres. Enforce them with Row Level Security and security-definer functions. Do not trust a role sent from the app.
4. Turn on Google in Supabase after the Cloud client IDs and redirect URLs exist. Test Android, iOS, and the website separately.
5. Send Gmail through a Supabase Edge Function or the Next.js server, using a secret that is not in the apps.

Flutter Web can be added with `flutter create --platforms=web` after the phone and the React site share Supabase. Doing it first would create a third interface before the shared data works.
