import { notFound } from "next/navigation";
import { submitClaim } from "@/app/actions";
import { SubmitButton } from "@/components/submit-button";
import { formatWhen, requireProfile, statusLabel } from "@/lib/campus";
import { createClient } from "@/lib/supabase/server";

type ItemRow = {
  id: string;
  ref: string;
  author_id: string;
  type: string;
  status: string;
  title: string;
  description: string;
  category: string;
  colour: string | null;
  location_id: string | null;
  created_at: string;
};

export default async function ItemPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; notice?: string }>;
}) {
  const profile = await requireProfile();
  const { id } = await params;
  const { error, notice } = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase
    .from("items")
    .select(
      "id, ref, author_id, type, status, title, description, category, colour, location_id, created_at",
    )
    .eq("id", id)
    .maybeSingle();
  const item = data as ItemRow | null;
  if (!item) notFound();

  const [{ data: author }, { data: place }, { data: photos }, { data: claims }] = await Promise.all([
    supabase.from("profiles").select("name").eq("id", item.author_id).maybeSingle(),
    item.location_id
      ? supabase.from("locations").select("name").eq("id", item.location_id).maybeSingle()
      : Promise.resolve({ data: null }),
    supabase.from("item_photos").select("file_path, position").eq("item_id", item.id).order("position"),
    supabase.from("claims").select("id, status").eq("item_id", item.id).eq("claimant_id", profile.id),
  ]);

  let photoUrl: string | null = null;
  const first = photos?.[0]?.file_path;
  if (first) {
    const signed = await supabase.storage.from("item-photos").createSignedUrl(first, 3600);
    photoUrl = signed.data?.signedUrl ?? null;
  }

  const canClaim =
    item.type === "found" &&
    item.status === "open" &&
    item.author_id !== profile.id &&
    (claims?.length ?? 0) === 0;

  return (
    <article className="grid gap-8 lg:grid-cols-[1.1fr_0.9fr]">
      <div>
        <p className="text-xs tracking-[0.14em] text-ink/50 uppercase">
          {item.ref} · {item.type} · {statusLabel(item.status)}
        </p>
        <h1 className="mt-2 font-serif text-5xl">{item.title}</h1>
        <p className="mt-4 text-lg text-ink/80">{item.description}</p>
        <dl className="mt-6 grid grid-cols-2 gap-3 text-sm">
          <Fact label="Category" value={item.category} />
          <Fact label="Colour" value={item.colour || "Not given"} />
          <Fact label="Place" value={place?.name || "Not given"} />
          <Fact label="Posted" value={formatWhen(item.created_at)} />
          <Fact label="Posted by" value={author?.name || "Campus member"} />
        </dl>
      </div>
      <div>
        <div className="overflow-hidden rounded-3xl border border-line bg-[#efe7da]">
          {photoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img alt="" className="aspect-[4/3] w-full object-cover" src={photoUrl} />
          ) : (
            <div className="flex aspect-[4/3] items-end p-6 font-serif text-3xl text-ink/30">{item.category}</div>
          )}
        </div>
        {error ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-brass">{error}</p> : null}
        {notice ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm">{notice}</p> : null}
        {canClaim ? (
          <form action={submitClaim} className="mt-4 grid gap-3 rounded-3xl border border-line bg-card p-5">
            <h2 className="font-serif text-2xl">This is mine</h2>
            <p className="text-sm text-ink/70">Claims are only opened on found items, and the database checks who can file one.</p>
            <input name="itemId" type="hidden" value={item.id} />
            <textarea
              className="min-h-24 rounded-xl border border-line px-3 py-2"
              name="description"
              placeholder="How do you know this is yours?"
              required
            />
            <input className="h-11 rounded-xl border border-line px-3" name="where" placeholder="Where you lost it" />
            <input className="h-11 rounded-xl border border-line px-3" name="when" placeholder="When you lost it" />
            <input accept="image/jpeg,image/png,image/webp" name="evidence" type="file" />
            <SubmitButton>Submit claim</SubmitButton>
          </form>
        ) : (
          <p className="mt-4 text-sm text-ink/60">
            {item.author_id === profile.id
              ? "This is your post."
              : item.type === "lost"
                ? "Lost posts are visible to the campus. Claims are opened on found items."
                : "A claim is already open, or this item is no longer available."}
          </p>
        )}
      </div>
    </article>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-line bg-card p-3">
      <dt className="text-xs text-ink/50">{label}</dt>
      <dd className="mt-1 font-medium">{value}</dd>
    </div>
  );
}
