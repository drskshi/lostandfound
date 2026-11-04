import Link from "next/link";
import { pageSize } from "@/lib/catalogue";
import { currentProfile, formatWhen } from "@/lib/campus";
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

export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; type?: string; q?: string }>;
}) {
  const profile = await currentProfile();
  const query = await searchParams;
  if (!profile) return <Welcome />;

  const page = Math.max(0, Number(query.page ?? "0") || 0);
  const type = query.type === "lost" || query.type === "found" ? query.type : "";
  const term = (query.q ?? "").replace(/[%_,]/g, "").trim();
  const supabase = await createClient();
  let request = supabase
    .from("items")
    .select(
      "id, ref, author_id, type, status, title, description, category, colour, location_id, created_at",
    )
    .order("created_at", { ascending: false })
    .range(page * pageSize, page * pageSize + pageSize);

  if (type) request = request.eq("type", type);
  if (term) request = request.or(`title.ilike.%${term}%,description.ilike.%${term}%`);

  const { data, error } = await request;
  const rows = ((data ?? []) as ItemRow[]).slice(0, pageSize);
  const hasNext = (data?.length ?? 0) > pageSize;
  const photos = await photoMap(rows.map((row) => row.id));
  const names = await nameMap(rows.map((row) => row.author_id));
  const places = await placeMap(rows.map((row) => row.location_id).filter(Boolean) as string[]);

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-serif text-4xl">Campus feed</h1>
          <p className="mt-1 text-ink/70">Posts from the website and the mobile app share this list.</p>
        </div>
        <Link className="rounded-full bg-pine px-5 py-3 font-medium text-white" href="/items/new">
          Post an item
        </Link>
      </div>
      <form className="mt-6 flex flex-wrap gap-2" method="get">
        <input
          className="h-11 min-w-56 flex-1 rounded-full border border-line bg-card px-4"
          defaultValue={term}
          name="q"
          placeholder="Search title or description"
        />
        <select className="h-11 rounded-full border border-line bg-card px-4" defaultValue={type} name="type">
          <option value="">Lost and found</option>
          <option value="lost">Lost</option>
          <option value="found">Found</option>
        </select>
        <button className="h-11 rounded-full border border-line bg-white px-4" type="submit">
          Update
        </button>
      </form>
      {error ? <p className="mt-6 text-brass">{error.message}</p> : null}
      {rows.length === 0 ? (
        <p className="mt-10 rounded-3xl border border-dashed border-line bg-card px-6 py-12 text-center text-ink/70">
          Nothing in this view yet. A post saved here, or from the signed-in mobile app, will appear in this feed.
        </p>
      ) : (
        <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {rows.map((item) => (
            <li key={item.id}>
              <Link className="block overflow-hidden rounded-3xl border border-line bg-card" href={`/items/${item.id}`}>
                <div className="relative aspect-[4/3] bg-[#efe7da]">
                  {photos.get(item.id) ? (
                    // Signed storage URLs expire, so they stay as a plain image.
                    // eslint-disable-next-line @next/next/no-img-element
                    <img alt="" className="h-full w-full object-cover" src={photos.get(item.id)} />
                  ) : (
                    <div className="flex h-full items-end p-4 font-serif text-2xl text-ink/30">{item.category}</div>
                  )}
                  <span className="absolute top-3 left-3 rounded-full bg-white/90 px-3 py-1 text-xs font-semibold uppercase">
                    {item.type}
                  </span>
                </div>
                <div className="p-4">
                  <p className="text-xs tracking-wide text-ink/50">{item.ref}</p>
                  <h2 className="mt-1 font-serif text-2xl">{item.title}</h2>
                  <p className="mt-2 line-clamp-2 text-sm text-ink/70">{item.description}</p>
                  <p className="mt-3 text-xs text-ink/55">
                    {names.get(item.author_id) ?? "Campus member"}
                    {places.get(item.location_id ?? "") ? ` · ${places.get(item.location_id ?? "")}` : ""}
                    {" · "}
                    {formatWhen(item.created_at)}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <div className="mt-6 flex gap-3">
        {page > 0 ? (
          <Link className="rounded-full border border-line px-4 py-2" href={feedHref(page - 1, type, term)}>
            Previous
          </Link>
        ) : null}
        {hasNext ? (
          <Link className="rounded-full border border-line px-4 py-2" href={feedHref(page + 1, type, term)}>
            Next
          </Link>
        ) : null}
      </div>
    </div>
  );
}

function feedHref(page: number, type: string, term: string) {
  const params = new URLSearchParams();
  if (page) params.set("page", String(page));
  if (type) params.set("type", type);
  if (term) params.set("q", term);
  const query = params.toString();
  return query ? `/?${query}` : "/";
}

function Welcome() {
  return (
    <section className="grid items-center gap-10 py-8 lg:grid-cols-[1.2fr_0.8fr]">
      <div>
        <p className="text-sm font-semibold tracking-[0.16em] text-brass uppercase">Northbridge College</p>
        <h1 className="mt-3 max-w-xl font-serif text-5xl leading-tight sm:text-6xl">
          One record for what the campus has lost and found.
        </h1>
        <p className="mt-5 max-w-lg text-lg text-ink/75">
          Sign in with the same account you use in the mobile app. Posts, photos, claims, and handovers stay in the shared campus database.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Link className="rounded-full bg-pine px-5 py-3 font-medium text-white" href="/login">
            Sign in
          </Link>
          <Link className="rounded-full border border-line bg-card px-5 py-3 font-medium" href="/register">
            Create an account
          </Link>
        </div>
      </div>
      <ul className="grid gap-3">
        {[
          ["Same sign-in", "Website and mobile use one Supabase account. A new account joins as a student."],
          ["Four roles", "Student, Sub-admin, Admin, and Superadmin. The database decides what each person can open."],
          ["Shared posts", "An item posted here is the same row the signed-in mobile app reads."],
        ].map(([title, body]) => (
          <li className="rounded-3xl border border-line bg-card p-5" key={title}>
            <h2 className="font-serif text-2xl">{title}</h2>
            <p className="mt-2 text-sm text-ink/70">{body}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}

async function photoMap(ids: string[]) {
  const map = new Map<string, string>();
  if (ids.length === 0) return map;
  const supabase = await createClient();
  const { data } = await supabase
    .from("item_photos")
    .select("item_id, file_path, position")
    .in("item_id", ids);
  const rows = [...(data ?? [])].sort((a, b) => a.position - b.position);
  for (const row of rows) {
    if (map.has(row.item_id) || !row.file_path) continue;
    const { data: signed } = await supabase.storage.from("item-photos").createSignedUrl(row.file_path, 3600);
    if (signed?.signedUrl) map.set(row.item_id, signed.signedUrl);
  }
  return map;
}

async function nameMap(ids: string[]) {
  const map = new Map<string, string>();
  const unique = [...new Set(ids)];
  if (unique.length === 0) return map;
  const supabase = await createClient();
  const { data } = await supabase.from("profiles").select("id, name").in("id", unique);
  for (const row of data ?? []) map.set(row.id, row.name);
  return map;
}

async function placeMap(ids: string[]) {
  const map = new Map<string, string>();
  const unique = [...new Set(ids)];
  if (unique.length === 0) return map;
  const supabase = await createClient();
  const { data } = await supabase.from("locations").select("id, name").in("id", unique);
  for (const row of data ?? []) map.set(row.id, row.name);
  return map;
}
