# Role permission matrix

`role_assignments` is the authority. `profiles.role` is a cache the client cannot update. Claim approval and collection-code redemption run only in `private.approve_claim` and `private.redeem_collection_code`.

| Action | Superadmin | Admin | Sub-admin | Student | Public |
| --- | --- | --- | --- | --- | --- |
| Read own institution's items | Yes | Yes | Yes | Yes | No |
| Read another institution | Yes | No | No | No | No |
| Create a department in an institution | Yes | That institution | No | No | No |
| Grant superadmin or institution admin | Yes | No | No | No | No |
| Grant student or sub-admin | Yes | That institution | No | No | No |
| Change own role | No | No | No | No | No |
| Review a claim in an assigned department | Yes | That institution | That department | No | No |
| Read another person's claim evidence | Yes, when they can review the claim | That institution | That department | No | No |
| Approve a claim | Yes | That institution | That department | No | No |
| Redeem a collection code | Yes | That institution | That department | No | No |
| Reuse an expired or used code | No | No | No | No | No |
| Own profile, posts, and own claims | Yes | Yes | Yes | Yes | No |

A person may hold more than one institution membership. Each grant is scoped to one institution, and a sub-admin grant is also scoped to one department.
