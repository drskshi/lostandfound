# Real SMTP test

Date: 1 November 2026

Sender account named for setup: duwadiksh15@gmail.com

Host: smtp.gmail.com
Port: 587
Encryption: STARTTLS

| Check | Result |
| --- | --- |
| Edge function `send-campus-email` deployed | PASS. Status ACTIVE. JWT is required. |
| Function chooses the recipient from the claim, not from the client | Implemented. Not exercised with a live message. |
| Duplicate send and hourly limit | Implemented. NOT TESTED. |
| App password stored in Supabase secrets | NOT SET from this session. The old exposed password must be revoked. The new password must be entered in the Supabase dashboard, not in chat or Git. |
| Real Gmail message received | BLOCKED |
| Claim notification email | BLOCKED |
| Failure and retry with a live mailbox | NOT TESTED |
| Supabase Auth verification and password-reset SMTP | NOT CONFIGURED in the Auth dashboard from this session |

Until `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_HOST`, and `SMTP_PORT` exist as function secrets, the function returns `sender-not-enabled` and does not send mail.

Auth emails stay in Supabase Authentication, SMTP settings. Claim emails stay in the edge function. The function refuses `verify` and `reset` so a client cannot pick an arbitrary recipient for those.
