# First superadmin

There is no public superadmin signup. A new account is a student. The database trigger `private.handle_new_user` writes that role and ignores signup metadata.

Provision the first platform owner from the Supabase SQL editor, which runs as the database owner. Do not put this in the Flutter app, the website, or a client key.

1. The owner creates a normal student account in the app or in Authentication → Users.
2. Copy that user's id from Authentication → Users.
3. Run this once:

```sql
select private.bootstrap_superadmin('<auth user uuid>');
```

The function refuses to run when any superadmin assignment already exists. It does not take an email or a password. Authenticated and anonymous clients cannot execute it.

Later superadmins are granted by an existing superadmin through `public.grant_role`. An institution admin cannot grant that role.
