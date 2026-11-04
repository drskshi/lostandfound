import { createItem } from "@/app/actions";
import { SubmitButton } from "@/components/submit-button";
import { categories, colours } from "@/lib/catalogue";
import { requireProfile } from "@/lib/campus";
import { createClient } from "@/lib/supabase/server";

export default async function NewItemPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const profile = await requireProfile();
  const { error } = await searchParams;
  const supabase = await createClient();
  const { data: locations } = await supabase
    .from("locations")
    .select("id, name")
    .eq("university_id", profile.university_id)
    .order("name");

  return (
    <section className="mx-auto max-w-xl">
      <h1 className="font-serif text-4xl">Post an item</h1>
      <p className="mt-2 text-ink/70">This is saved in the same table the mobile app reads.</p>
      {error ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-brass">{error}</p> : null}
      <form action={createItem} className="mt-6 grid gap-4">
        <fieldset className="flex gap-2">
          <Choice name="type" value="lost" label="Lost" defaultChecked />
          <Choice name="type" value="found" label="Found" />
        </fieldset>
        <Field label="Title" name="title" required />
        <label className="grid gap-1.5 text-sm font-medium">
          Description
          <textarea className="min-h-28 rounded-xl border border-line bg-card px-3 py-2" name="description" required />
        </label>
        <div className="grid gap-4 sm:grid-cols-2">
          <Select label="Category" name="category" options={categories} />
          <Select label="Colour" name="colour" options={colours} />
        </div>
        <label className="grid gap-1.5 text-sm font-medium">
          Place
          <select className="h-12 rounded-xl border border-line bg-card px-3" name="locationId">
            <option value="">Not sure</option>
            {(locations ?? []).map((place) => (
              <option key={place.id} value={place.id}>
                {place.name}
              </option>
            ))}
          </select>
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Private note for a found item
          <textarea
            className="min-h-20 rounded-xl border border-line bg-card px-3 py-2"
            name="privateDetails"
            placeholder="Kept off the public feed"
          />
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Photo
          <input accept="image/jpeg,image/png,image/webp" className="text-sm" name="photo" type="file" />
        </label>
        <SubmitButton>Publish</SubmitButton>
      </form>
    </section>
  );
}

function Field({ label, name, required }: { label: string; name: string; required?: boolean }) {
  return (
    <label className="grid gap-1.5 text-sm font-medium">
      {label}
      <input className="h-12 rounded-xl border border-line bg-card px-3" name={name} required={required} />
    </label>
  );
}

function Select({ label, name, options }: { label: string; name: string; options: readonly string[] }) {
  return (
    <label className="grid gap-1.5 text-sm font-medium">
      {label}
      <select className="h-12 rounded-xl border border-line bg-card px-3" name={name}>
        {options.map((option) => (
          <option key={option}>{option}</option>
        ))}
      </select>
    </label>
  );
}

function Choice({
  name,
  value,
  label,
  defaultChecked,
}: {
  name: string;
  value: string;
  label: string;
  defaultChecked?: boolean;
}) {
  return (
    <label className="flex-1">
      <input className="peer sr-only" defaultChecked={defaultChecked} name={name} type="radio" value={value} />
      <span className="block rounded-full border border-line bg-card py-3 text-center peer-checked:border-pine peer-checked:bg-pine peer-checked:text-white">
        {label}
      </span>
    </label>
  );
}
