# Gmail SMTP

The app does not send mail. A server function is prepared at `supabase/functions/send-campus-email/index.ts`. It refuses every message until two secrets exist. Those secrets must never be put in Flutter, `web/`, or Git.

## What you do once

1. On the Gmail account, turn on 2-Step Verification.
2. Create an App Password. Google shows it once. Copy it somewhere private, not into this repository.
3. In Supabase, open Edge Functions, then Secrets, and add:
   - `SMTP_USER` = the Gmail address
   - `SMTP_PASSWORD` = the app password
   - `SMTP_HOST` = `smtp.gmail.com`
   - `SMTP_PORT` = `587`
4. Deploy the function from this folder after the Supabase CLI is logged in:

```sh
supabase functions deploy send-campus-email --project-ref iuitbmbovoroffkwwlfk
```

The function still returns "sender-not-enabled" after the secrets exist. The SMTP conversation itself is not implemented yet, so no verification, reset, or claim email is sent.

## Messages the function is allowed to know about

- Email verification
- Password reset
- Claim submitted
- Claim approved
- Claim rejected
- Additional evidence requested
- Item ready for collection
- Handover confirmation

## Current result

Mail delivery: NOT TESTED, and not enabled.
