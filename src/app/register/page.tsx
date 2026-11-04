import Link from "next/link";
import { registerAccount } from "@/app/actions";
import { SubmitButton } from "@/components/submit-button";
import { supabaseConfigured } from "@/lib/supabase/server";

export default async function RegisterPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; notice?: string }>;
}) {
  const { error, notice } = await searchParams;
  return (
    <section className="mx-auto max-w-md">
      <h1 className="font-serif text-4xl">Create an account</h1>
      <p className="mt-2 text-ink/70">The campus database assigns the student role. You cannot choose a staff role here.</p>
      {error ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-brass">{error}</p> : null}
      {notice ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm">{notice}</p> : null}
      {supabaseConfigured() ? null : (
        <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-brass">
          This deployment is not connected to the campus database yet.
        </p>
      )}
      <form action={registerAccount} className="mt-6 grid gap-4">
        <label className="grid gap-1.5 text-sm font-medium">
          Name
          <input className="h-12 rounded-xl border border-line bg-card px-3" name="name" required />
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Email
          <input
            className="h-12 rounded-xl border border-line bg-card px-3"
            name="email"
            placeholder="name@university.ac.uk"
            type="email"
            required
          />
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Department
          <input className="h-12 rounded-xl border border-line bg-card px-3" name="department" />
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Password
          <input className="h-12 rounded-xl border border-line bg-card px-3" minLength={10} name="password" type="password" required />
        </label>
        <SubmitButton>Create account</SubmitButton>
      </form>
      <p className="mt-6 text-sm">
        Already registered?{" "}
        <Link className="font-medium underline" href="/login">
          Sign in
        </Link>
      </p>
    </section>
  );
}
