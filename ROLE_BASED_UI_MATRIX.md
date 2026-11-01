# Role-based UI matrix

Date: 1 November 2026.

The database roles are Superadmin, Admin, Sub-admin, and Student. The screens below do not replace those rules. A build of the app does not grant access.

| Screen | Superadmin | Admin | Sub-admin | Student | Public |
| --- | --- | --- | --- | --- | --- |
| Flutter `/superadmin` | Opens | Closed | Closed | Closed | Sign-in wall |
| Flutter `/institution-admin` | Closed | Opens | Closed | Closed | Sign-in wall |
| Flutter `/department-admin` | Closed | Closed | Opens | Closed | Sign-in wall |
| Flutter `/student` | Closed | Closed | Closed | Opens | Sign-in wall |
| Website `/access/superadmin` | Opens only if the stored role is exactly `superadmin` | Closed | Closed | Closed | Sign-in wall |
| Website `/access/admin` | Closed | Opens only if the stored role is exactly `admin` | Closed | Closed | Sign-in wall |
| Website `/access/subadmin` | Closed | Closed | Opens only if the stored role is exactly `subadmin` | Closed | Sign-in wall |
| Website `/access/student` | Closed | Closed | Closed | Opens only if the stored role is exactly `student` | Sign-in wall |

The Flutter dashboards list duties. They cannot change a role, approve a claim, or redeem a collection code.

The website office at `/admin` still uses `MEMBER`, `STAFF`, and `ADMIN` on SQLite. Those names do not open the four `/access` pages. The live Vercel demo is a separate browser demo and is not this matrix.

On every platform, institution and department isolation for real records is the Supabase policy layer. The Flutter screens still filter the on-device demo. They do not yet load another institution's private claims from Supabase, and they also do not yet enforce that boundary in the interface.
