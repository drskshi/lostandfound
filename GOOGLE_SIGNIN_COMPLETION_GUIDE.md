# Google sign-in

Google Cloud and the Supabase Google provider are already set up. Do not create a new OAuth client. The Flutter app never contains the client secret. It starts Supabase Auth, and Supabase talks to Google.

## Redirect URLs to add

In Supabase, open Authentication, then URL Configuration, then add each of these under Redirect URLs:

```text
com.powerrangers.lostfound://login-callback
http://localhost:3000/**
http://127.0.0.1:3000/**
```

Leave the live React Vercel address off this list. That site does not handle this app's callback.

## Identifiers to check

| Platform | Value |
| --- | --- |
| Android application id | `com.powerrangers.lost_found_mobile` |
| iOS bundle id | `com.powerrangers.lostFoundMobile` |
| Deep link | `com.powerrangers.lostfound://login-callback` |

The Android manifest and the iOS Info.plist already accept that link.

## How to run a test

Web, from this folder:

```sh
flutter run -d chrome --web-port 3000 --dart-define-from-file=config/supabase.dev.json
```

Android and iOS use the same define file:

```sh
flutter run --dart-define-from-file=config/supabase.dev.json
```

Press Continue with Google. Closing the Google page shows "Google sign-in was cancelled." A new account is stored as a student by the database trigger. The button cannot choose Superadmin, Admin, or Sub-admin.

## If Google says the app is in testing

Open Google Cloud, then Google Auth Platform, then Audience. Add the Gmail address you use for the pitch under Test users. You do not need a new client secret for that.

## What was not completed

A live Google consent was not finished in this session, so the login result is BLOCKED until you press the button on a build that includes the publishable key.
