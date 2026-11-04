import Link from "next/link";
import { formatWhen, requireProfile, statusLabel } from "@/lib/campus";
import { createClient } from "@/lib/supabase/server";

type ClaimRow = {
  id: string;
  item_id: string;
  status: string;
  details: string;
  lost_where: string | null;
  decision_note: string | null;
  created_at: string;
};

export default async function ClaimsPage() {
  const profile = await requireProfile();
  const supabase = await createClient();
  const { data } = await supabase
    .from("claims")
    .select("id, item_id, status, details, lost_where, decision_note, created_at")
    .eq("claimant_id", profile.id)
    .order("created_at", { ascending: false });
  const claims = (data ?? []) as ClaimRow[];
  const titles = new Map<string, string>();
  if (claims.length > 0) {
    const { data: items } = await supabase
      .from("items")
      .select("id, title")
      .in("id", claims.map((claim) => claim.item_id));
    for (const item of items ?? []) titles.set(item.id, item.title);
  }

  return (
    <section>
      <h1 className="font-serif text-4xl">Your claims</h1>
      <p className="mt-2 text-ink/70">A claim filed here or in the mobile app uses the same record.</p>
      {claims.length === 0 ? (
        <p className="mt-8 rounded-3xl border border-dashed border-line bg-card px-6 py-12 text-center text-ink/70">
          You have not opened a claim yet.
        </p>
      ) : (
        <ul className="mt-6 grid gap-3">
          {claims.map((claim) => (
            <li className="rounded-3xl border border-line bg-card p-5" key={claim.id}>
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <Link className="font-serif text-2xl" href={`/items/${claim.item_id}`}>
                  {titles.get(claim.item_id) ?? "Campus item"}
                </Link>
                <span className="text-sm">{statusLabel(claim.status)}</span>
              </div>
              <p className="mt-2 text-sm text-ink/75">{claim.details}</p>
              {claim.decision_note ? <p className="mt-2 text-sm">Note: {claim.decision_note}</p> : null}
              <p className="mt-3 text-xs text-ink/50">{formatWhen(claim.created_at)}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
