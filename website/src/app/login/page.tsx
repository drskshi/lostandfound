import Link from "next/link";
import { signIn, signInWithGoogle } from "@/app/actions";
import { SubmitButton } from "@/components/submit-button";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <section className="mx-auto max-w-md">
      <h1 className="font-serif text-4xl">Sign in</h1>
      <p className="mt-2 text-ink/70">Use the campus account. New accounts join as students.</p>
      {error ? <p className="mt-4 rounded-2xl bg-white px-4 py-3 text-sm text-brass">{error}</p> : null}
      <form action={signIn} className="mt-6 grid gap-4">
        <label className="grid gap-1.5 text-sm font-medium">
          Email
          <input className="h-12 rounded-xl border border-line bg-card px-3" name="email" type="email" required />
        </label>
        <label className="grid gap-1.5 text-sm font-medium">
          Password
          <input className="h-12 rounded-xl border border-line bg-card px-3" name="password" type="password" required />
        </label>
        <SubmitButton>Sign in</SubmitButton>
      </form>
      <form action={signInWithGoogle} className="mt-3">
        <button className="h-12 w-full rounded-full border border-line bg-card font-medium" type="submit">
          Continue with Google
        </button>
      </form>
      <p className="mt-6 text-sm">
        New here?{" "}
        <Link className="font-medium underline" href="/register">
          Create an account
        </Link>
      </p>
    </section>
  );
}
