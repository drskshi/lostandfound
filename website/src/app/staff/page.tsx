import Link from "next/link";
import { DecisionForm, RedeemForm } from "@/components/claim-actions";
import { formatWhen, isStaff, requireProfile, statusLabel } from "@/lib/campus";
import { createClient } from "@/lib/supabase/server";

type ClaimRow = {
  id: string;
  item_id: string;
  claimant_id: string;
  status: string;
  details: string;
  lost_where: string | null;
  decision_note: string | null;
  handover_code_expires_at: string | null;
  created_at: string;
};

export default async function StaffPage() {
  const profile = await requireProfile();
  if (!isStaff(profile.role)) {
    return (
      <section className="max-w-lg">
        <h1 className="font-serif text-4xl">Review</h1>
        <p className="mt-3 text-ink/70">
          Students can post and claim. Approving a claim stays with campus staff, and the database enforces that.
        </p>
      </section>
    );
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("claims")
    .select(
      "id, item_id, claimant_id, status, details, lost_where, decision_note, handover_code_expires_at, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(40);
  const claims = (data ?? []) as ClaimRow[];
  const titles = new Map<string, string>();
  const names = new Map<string, string>();
  if (claims.length > 0) {
    const [{ data: items }, { data: people }] = await Promise.all([
      supabase.from("items").select("id, title").in("id", claims.map((claim) => claim.item_id)),
      supabase.from("profiles").select("id, name").in("id", claims.map((claim) => claim.claimant_id)),
    ]);
    for (const item of items ?? []) titles.set(item.id, item.title);
    for (const person of people ?? []) names.set(person.id, person.name);
  }

  return (
    <section>
      <h1 className="font-serif text-4xl">Claim review</h1>
      <p className="mt-2 max-w-2xl text-ink/70">
        You only see claims your role is allowed to review. Approve, decline, and handover run through the shared campus functions.
      </p>
      {claims.length === 0 ? (
        <p className="mt-8 rounded-3xl border border-dashed border-line bg-card px-6 py-12 text-center text-ink/70">
          No claims are waiting in your area.
        </p>
      ) : (
        <ul className="mt-6 grid gap-4">
          {claims.map((claim) => (
            <li className="rounded-3xl border border-line bg-card p-5" key={claim.id}>
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <Link className="font-serif text-2xl" href={`/items/${claim.item_id}`}>
                  {titles.get(claim.item_id) ?? "Campus item"}
                </Link>
                <span className="text-sm">{statusLabel(claim.status)}</span>
              </div>
              <p className="mt-2 text-sm text-ink/60">{names.get(claim.claimant_id) ?? "Student"}</p>
              <p className="mt-2 text-sm">{claim.details}</p>
              {claim.lost_where ? <p className="mt-1 text-sm text-ink/70">Lost at {claim.lost_where}</p> : null}
              {claim.decision_note ? <p className="mt-2 text-sm">Note: {claim.decision_note}</p> : null}
              <p className="mt-3 text-xs text-ink/50">{formatWhen(claim.created_at)}</p>
              {claim.status === "pending" || claim.status === "needs_info" ? (
                <DecisionForm claimId={claim.id} />
              ) : null}
              {claim.status === "approved" ? <RedeemForm claimId={claim.id} /> : null}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
