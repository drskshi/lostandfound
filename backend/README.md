# Shared database

Migrations `002_lost_found_supabase.sql` and `003_four_level_roles.sql` are applied on the Lost & Found Supabase project. The website still uses SQLite. `DATA_SOURCE` stays `sqlite` until a cutover is approved.

Roles in the database are `superadmin`, `admin`, `subadmin`, and `student`. New accounts become students. The first superadmin is created only with the SQL in `BOOTSTRAP_SUPERADMIN.md`. Clients cannot call that function.

`001_shared_postgres.sql` is the earlier Prisma-shaped draft. Do not apply it.

Flutter reads the project from gitignored `config/supabase.dev.json`:

```sh
cp config/supabase.dev.json.example config/supabase.dev.json
dart run tool/check_supabase.dart
flutter run --dart-define-from-file=config/supabase.dev.json
```

Use the publishable key. Do not put a secret or service-role key in the app, the website, or git.

Website check, from `uni-lost-and-found`, after filling `.env.local`:

```sh
node scripts/check-supabase.mjs
node scripts/check-roles.mjs
```

The phone demo still uses its local roles `member`, `staff`, and `admin`. The website's SQLite roles stay `MEMBER`, `STAFF`, and `ADMIN`. Those names do not open the four role dashboards except the phone's stored `admin`, which can open the institution screen. That screen does not grant database access.
