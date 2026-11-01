# Physical phone testing

These steps are preparation only. A physical Android phone and a physical iPhone were not tested.

## Android

1. On the phone, open Settings, About phone, and tap the build number until developer options turn on.
2. Open Developer options and turn on USB debugging.
3. Connect the phone with a cable and accept the computer prompt.
4. From this project folder, run `flutter devices`.
5. Run `flutter run -d <device-id> --dart-define-from-file=config/supabase.dev.json`.
6. The Google return address is `com.powerrangers.lostfound://login-callback`.
7. The Android application id is `com.powerrangers.lost_found_mobile`.

## iPhone

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the Runner target and set a development team under Signing & Capabilities.
3. Connect the iPhone and trust the computer.
4. From this project folder, run `flutter devices`.
5. Run `flutter run -d <device-id> --dart-define-from-file=config/supabase.dev.json`.
6. The iOS bundle id is `com.powerrangers.lostFoundMobile`.
7. The Google return address is the same `com.powerrangers.lostfound://login-callback` scheme.

## Google sign-in on a phone

1. Add `com.powerrangers.lostfound://login-callback` to the Supabase redirect allow list if it is not already there.
2. If Google says the app is in testing, add the account under Google Auth Platform, Audience, Test users.
3. Tap Continue with Google, choose the account, and allow the return to the app.
4. Confirm the student dashboard opens, then sign out and reopen the app to check that the session returns.
5. Record the result as PASS only after that session exists. Until then the phone result is NOT TESTED.
