# Platform test report

Date: 1 November 2026. Commands were run in `lost_found_mobile`. The builds did not use `config/supabase.dev.json`, so Supabase did not start in these binaries.

A passing web build is the current phone UI compiled for the browser. It is not feature parity with the React site, and the live Vercel deployment was not changed.

## Static analysis

| Command | Result |
| --- | --- |
| `flutter analyze` | PASS. No issues. |

## Automated tests

| Command | Result |
| --- | --- |
| `flutter test` | FAIL. 12 passed, 1 failed. |
| `test/widget_test.dart` "sign in opens the campus feed" | FAIL. Expected the text "Sign in" and found no widget. |
| `test/page_window_test.dart` | PASS |
| `test/campus_store_test.dart` | PASS |
| `test/access_role_test.dart` | PASS |

## Builds

| Command | Result | Output |
| --- | --- | --- |
| `flutter build web` | PASS in 85.2s | `build/web` |
| `flutter build apk --debug` | PASS in 46.9s | `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --simulator` | PASS in 53.0s | `build/ios/iphonesimulator/Runner.app` |

## Functional checks

| Platform | Result | What was actually done |
| --- | --- | --- |
| Web | PARTIAL | Served `build/web` at `http://127.0.0.1:8765/`. The page title was Lost & Found and the route was `/#/onboarding`. The intro showed the campus feed, private claims, and collection-code text, plus Continue. Sign-in, feed, and role screens were not exercised. |
| Android | BLOCKED | Debug APK built. No emulator or device session was run. |
| iOS | BLOCKED | Simulator app built. The Simulator was not launched. |

## Not tested

- Shared Supabase reads and writes from any screen
- Google sign-in
- Email delivery
- Desktop and tablet layouts
- Replacing the live React site
