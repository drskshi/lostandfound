# Real Google sign-in test

Date: 1 November 2026

The web app was started with the existing Supabase configuration on http://localhost:3000. Supabase printed that initialization completed, and the login page said sign-in uses the shared campus database.

| Platform | Consent completed | Callback | Session | Profile | Student role | Logout | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Flutter Web | No. The login page is open. The owner must click Continue with Google. | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | BLOCKED |
| Android | No | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| iOS | No | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |

No access token or refresh token was printed.

What the owner clicks:

1. On http://localhost:3000/login, click Continue with Google.
2. Choose the permitted Google account.
3. If Google asks for permission, click Allow. Do not use a bypass.
4. The browser should return to http://localhost:3000. The student dashboard should open.
5. If Google says the redirect is not allowed, add these in Supabase Authentication, URL configuration:

```text
com.powerrangers.lostfound://login-callback
http://localhost:3000/**
http://127.0.0.1:3000/**
```

6. If Google says the app is in testing, add the account under Google Auth Platform, Audience, Test users.

Android application id: `com.powerrangers.lost_found_mobile`

iOS bundle id: `com.powerrangers.lostFoundMobile`
