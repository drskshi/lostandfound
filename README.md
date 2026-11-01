# Lost & Found

Native Flutter app for the campus lost-and-found flows. It follows the live campus demo’s blue and white layout. Posts, claims and photos stay on this phone. Google sign-in and email are not connected, and this is not a university single sign-on.

## Run

```bash
flutter pub get
flutter run
```

Sample accounts use the password `lost-and-found-demo`. They are listed on the sign-in screen. Staff and admin access comes from the saved account, not from a role picker.

- `amara@ravensbourne.example` student
- `tom@ravensbourne.example` student who can review claims on items he found
- `dave@ravensbourne.example` lost property office
- `rachel@ravensbourne.example` campus admin
- `leo@kingsmere.example` a second sample campus that cannot see Ravensbourne posts
