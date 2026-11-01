// Claim mail stays on the server. Supabase Auth verification and password
// reset use the project's Auth SMTP settings, not this function, so a client
// cannot choose an arbitrary recipient.
import { createClient } from "npm:@supabase/supabase-js@2.49.1";
import nodemailer from "npm:nodemailer@6.9.16";

const claimKinds = new Set([
  "claim_submitted",
  "claim_approved",
  "claim_rejected",
  "claim_evidence",
  "ready_for_collection",
  "handover",
]);

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const auth = request.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) {
    return new Response("Missing session", { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const kind = body?.kind;
  const claimId = body?.claimId;
  if (kind === "verify" || kind === "reset") {
    return Response.json({ accepted: false, reason: "use-auth-mail" }, { status: 400 });
  }
  if (typeof kind !== "string" || !claimKinds.has(kind)) {
    return new Response("Unknown message", { status: 400 });
  }
  if (typeof claimId !== "string" || !/^[0-9a-f-]{36}$/i.test(claimId)) {
    return new Response("Unknown claim", { status: 400 });
  }

  const smtpUser = Deno.env.get("SMTP_USER") ?? "";
  const smtpPassword = Deno.env.get("SMTP_PASSWORD") ?? "";
  if (!smtpUser || !smtpPassword) {
    return Response.json({ accepted: false, reason: "sender-not-enabled" }, { status: 503 });
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !anon || !service) {
    return Response.json({ accepted: false, reason: "sender-not-enabled" }, { status: 503 });
  }

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });
  const userResult = await userClient.auth.getUser();
  const caller = userResult.data.user?.id;
  if (!caller) return new Response("Missing session", { status: 401 });

  const admin = createClient(url, service, { auth: { persistSession: false } });
  const claimResult = await admin
    .from("claims")
    .select("id, claimant_id, item_id, status, decided_by, created_at")
    .eq("id", claimId)
    .maybeSingle();
  const claim = claimResult.data;
  if (!claim) return new Response("Unknown claim", { status: 404 });

  const itemResult = await admin
    .from("items")
    .select("id, author_id, university_id, title")
    .eq("id", claim.item_id)
    .maybeSingle();
  const item = itemResult.data;
  if (!item) return new Response("Unknown claim", { status: 404 });

  let recipientId = "";
  if (kind === "claim_submitted") {
    if (claim.claimant_id !== caller || claim.status !== "pending") {
      return new Response("Not allowed", { status: 403 });
    }
    const age = Date.now() - Date.parse(claim.created_at);
    if (!Number.isFinite(age) || age > 15 * 60 * 1000) {
      return new Response("Not allowed", { status: 403 });
    }
    recipientId = item.author_id;
  } else if (claim.decided_by !== caller) {
    return new Response("Not allowed", { status: 403 });
  } else if (kind === "handover" && claim.status !== "completed") {
    return new Response("Not allowed", { status: 409 });
  } else {
    recipientId = claim.claimant_id;
  }

  const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const duplicate = await admin
    .from("audit_logs")
    .select("id")
    .eq("action", `email.${kind}`)
    .eq("target_id", claimId)
    .gte("created_at", since);
  if ((duplicate.data ?? []).length > 0) {
    return Response.json({ accepted: true, reason: "already-sent" });
  }

  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const recent = await admin
    .from("audit_logs")
    .select("id")
    .eq("actor_id", caller)
    .like("action", "email.%")
    .gte("created_at", hourAgo);
  if ((recent.data ?? []).length >= 20) {
    return Response.json({ accepted: false, reason: "rate-limited" }, { status: 429 });
  }

  const profile = await admin
    .from("profiles")
    .select("email, university_id")
    .eq("id", recipientId)
    .maybeSingle();
  const to = profile.data?.email ?? "";
  if (!to.includes("@")) {
    return Response.json({ accepted: false, reason: "delivery-failed" }, { status: 422 });
  }

  const text = messageFor(kind, item.title ?? "an item");
  try {
    const transport = nodemailer.createTransport({
      host: Deno.env.get("SMTP_HOST") || "smtp.gmail.com",
      port: Number(Deno.env.get("SMTP_PORT") || "587"),
      secure: false,
      auth: { user: smtpUser, pass: smtpPassword },
    });
    await transport.sendMail({
      from: smtpUser,
      to,
      subject: text.subject,
      text: text.body,
    });
  } catch (_error) {
    return Response.json({ accepted: false, reason: "delivery-failed" }, { status: 502 });
  }

  await admin.from("audit_logs").insert({
    university_id: item.university_id,
    actor_id: caller,
    action: `email.${kind}`,
    target_type: "claim",
    target_id: claimId,
    summary: "Sent a campus notification.",
  });
  await admin.from("notifications").insert({
    user_id: recipientId,
    kind,
    title: text.subject,
    body: text.body,
    href: `/claims/${claimId}`,
  });
  return Response.json({ accepted: true });
});

function messageFor(kind: string, title: string): { subject: string; body: string } {
  switch (kind) {
    case "claim_submitted":
      return {
        subject: `New claim for ${title}`,
        body: "A claim was submitted. Open Lost & Found to review it. Do not share private evidence.",
      };
    case "claim_approved":
    case "ready_for_collection":
      return {
        subject: `Claim approved for ${title}`,
        body: "The claim was approved. Open the app for the one-time collection code.",
      };
    case "claim_rejected":
      return {
        subject: `Claim not approved for ${title}`,
        body: "The claim was not approved. Open Lost & Found for the decision note.",
      };
    case "claim_evidence":
      return {
        subject: `More information needed for ${title}`,
        body: "The reviewer asked for more information. Open the claim in Lost & Found.",
      };
    default:
      return {
        subject: `Handover recorded for ${title}`,
        body: "The handover was recorded. Open Lost & Found if you need the receipt.",
      };
  }
}
