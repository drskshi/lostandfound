"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { categories, colours } from "@/lib/catalogue";
import { isStaff, readableError, requireProfile } from "@/lib/campus";
import { createClient } from "@/lib/supabase/server";

function clean(value: FormDataEntryValue | null) {
  return typeof value === "string" ? value.trim() : "";
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

async function siteOrigin() {
  const headerList = await headers();
  return headerList.get("origin") || process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
}

export async function signIn(formData: FormData) {
  const email = clean(formData.get("email")).toLowerCase();
  const password = String(formData.get("password") ?? "");
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) redirect(`/login?error=${encodeURIComponent(readableError(error.message))}`);
  redirect("/");
}

export async function signInWithGoogle() {
  const supabase = await createClient();
  const origin = await siteOrigin();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: `${origin}/auth/callback` },
  });
  if (error || !data.url) {
    redirect(`/login?error=${encodeURIComponent(readableError(error?.message ?? "Google sign-in did not open."))}`);
  }
  redirect(data.url);
}

export async function registerAccount(formData: FormData) {
  const name = clean(formData.get("name"));
  const email = clean(formData.get("email")).toLowerCase();
  const password = String(formData.get("password") ?? "");
  const department = clean(formData.get("department"));
  if (name.length < 2) redirect("/register?error=Enter%20your%20name.");
  if (!email.includes("@") || email.startsWith("@")) {
    redirect("/register?error=Enter%20an%20email%20address.");
  }
  if (password.length < 10) redirect("/register?error=Use%20at%20least%2010%20characters.");

  const supabase = await createClient();
  const origin = await siteOrigin();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { name },
      emailRedirectTo: `${origin}/auth/callback`,
    },
  });
  if (error) redirect(`/register?error=${encodeURIComponent(readableError(error.message))}`);
  if (!data.user || !data.session) {
    redirect("/register?notice=Check%20your%20email%20to%20confirm%20the%20account.%20New%20accounts%20join%20as%20students.");
  }
  await supabase.from("profiles").update({ name, department }).eq("id", data.user.id);
  redirect("/");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function createItem(formData: FormData) {
  const profile = await requireProfile();
  const type = clean(formData.get("type"));
  const title = clean(formData.get("title"));
  const description = clean(formData.get("description"));
  const category = clean(formData.get("category"));
  const colour = clean(formData.get("colour"));
  const placeId = clean(formData.get("locationId"));
  const privateDetails = clean(formData.get("privateDetails"));

  if (type !== "lost" && type !== "found") {
    redirect("/items/new?error=Choose%20lost%20or%20found.");
  }
  if (title.length < 3) redirect("/items/new?error=Add%20a%20short%20title.");
  if (description.length < 10) {
    redirect("/items/new?error=Describe%20the%20item%20in%20a%20sentence%20or%20two.");
  }
  if (!categories.includes(category as (typeof categories)[number])) {
    redirect("/items/new?error=Choose%20a%20category.");
  }
  if (!colours.includes(colour as (typeof colours)[number])) {
    redirect("/items/new?error=Choose%20a%20colour.");
  }

  const supabase = await createClient();
  const { data: inserted, error } = await supabase
    .from("items")
    .insert({
      university_id: profile.university_id,
      author_id: profile.id,
      type,
      title,
      description,
      category,
      colour,
      location_id: isUuid(placeId) ? placeId : null,
      sensitive: false,
      custody: isStaff(profile.role) && type === "found" ? "office" : "finder",
      private_details: type === "found" ? privateDetails : "",
      retain_until: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    })
    .select("id")
    .single();

  if (error || !inserted) {
    redirect(`/items/new?error=${encodeURIComponent(readableError(error?.message ?? ""))}`);
  }

  const photo = formData.get("photo");
  if (photo instanceof File && photo.size > 0) {
    if (photo.size > 5_000_000) {
      redirect(`/items/${inserted.id}?notice=The%20item%20is%20posted.%20The%20photo%20was%20too%20large.`);
    }
    const path = `${profile.id}/${inserted.id}/${Date.now()}.jpg`;
    const bytes = new Uint8Array(await photo.arrayBuffer());
    const uploaded = await supabase.storage.from("item-photos").upload(path, bytes, {
      contentType: photo.type || "image/jpeg",
      upsert: false,
    });
    if (!uploaded.error) {
      await supabase.from("item_photos").insert({
        item_id: inserted.id,
        file_path: path,
        width: 0,
        height: 0,
        position: 0,
      });
    }
  }

  redirect(`/items/${inserted.id}`);
}

export async function submitClaim(formData: FormData) {
  const profile = await requireProfile();
  const itemId = clean(formData.get("itemId"));
  const description = clean(formData.get("description"));
  const where = clean(formData.get("where"));
  const when = clean(formData.get("when"));
  if (!isUuid(itemId)) redirect("/");
  if (description.length < 10) {
    redirect(`/items/${itemId}?error=Describe%20how%20you%20know%20this%20is%20yours.`);
  }

  let proof: string | null = null;
  const evidence = formData.get("evidence");
  const supabase = await createClient();
  if (evidence instanceof File && evidence.size > 0 && evidence.size <= 5_000_000) {
    const path = `${profile.id}/pending/${Date.now()}.jpg`;
    const bytes = new Uint8Array(await evidence.arrayBuffer());
    const uploaded = await supabase.storage.from("claim-evidence").upload(path, bytes, {
      contentType: evidence.type || "image/jpeg",
      upsert: false,
    });
    if (!uploaded.error) proof = path;
  }

  const { error } = await supabase.from("claims").insert({
    item_id: itemId,
    claimant_id: profile.id,
    details: when ? `${description}\nWhen: ${when}` : description,
    lost_where: where,
    proof_path: proof,
  });
  if (error) {
    redirect(`/items/${itemId}?error=${encodeURIComponent(readableError(error.message))}`);
  }
  redirect("/claims");
}

export type DecisionState = { message: string; code?: string } | null;

export async function decideClaim(_prev: DecisionState, formData: FormData): Promise<DecisionState> {
  const profile = await requireProfile();
  if (!isStaff(profile.role)) return { message: "Reviews are for campus staff." };
  const claimId = clean(formData.get("claimId"));
  const decision = clean(formData.get("decision"));
  const note = clean(formData.get("note"));
  if (!isUuid(claimId)) return { message: "That claim could not be found." };

  const supabase = await createClient();
  if (decision === "approve") {
    const { data, error } = await supabase.rpc("approve_claim", {
      p_claim_id: claimId,
      p_note: note,
    });
    if (error) return { message: readableError(error.message) };
    const code = typeof data === "string" ? data : "";
    return {
      message: "Approved. The collection code is also saved for the claimant.",
      code,
    };
  }

  const fn = decision === "reject" ? "reject_claim" : "request_claim_info";
  const { error } = await supabase.rpc(fn, { p_claim_id: claimId, p_note: note });
  if (error) return { message: readableError(error.message) };
  return {
    message: decision === "reject" ? "The claim was declined." : "More detail was requested.",
  };
}

export async function redeemCode(_prev: DecisionState, formData: FormData): Promise<DecisionState> {
  const profile = await requireProfile();
  if (!isStaff(profile.role)) return { message: "Handover is for campus staff." };
  const claimId = clean(formData.get("claimId"));
  const code = clean(formData.get("code"));
  if (!isUuid(claimId) || code.length < 4) return { message: "Enter the collection code." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("redeem_collection_code", {
    p_claim_id: claimId,
    p_code: code,
  });
  if (error) return { message: readableError(error.message) };
  return { message: "Handover recorded." };
}
