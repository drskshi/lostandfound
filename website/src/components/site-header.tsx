import Link from "next/link";
import { signOut } from "@/app/actions";
import { isStaff, roleLabel, type Profile } from "@/lib/campus";

export function SiteHeader({ profile }: { profile: Profile | null }) {
  return (
    <header className="sticky top-0 z-20 border-b border-line bg-paper/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center gap-4 px-5 py-3">
        <Link href="/" className="min-w-0">
          <p className="text-[11px] font-semibold tracking-[0.16em] text-brass uppercase">
            Northbridge College
          </p>
          <p className="font-serif text-xl leading-none text-ink">Lost &amp; Found</p>
        </Link>
        <nav className="ml-auto flex items-center gap-1 text-sm">
          {profile ? (
            <>
              <NavLink href="/">Feed</NavLink>
              <NavLink href="/items/new">Post</NavLink>
              <NavLink href="/claims">Claims</NavLink>
              {isStaff(profile.role) ? <NavLink href="/staff">Review</NavLink> : null}
              <span className="mx-2 hidden text-ink/50 sm:inline">
                {profile.name} · {roleLabel(profile.role)}
              </span>
              <form action={signOut}>
                <button className="rounded-full px-3 py-2 text-ink/80 hover:bg-white" type="submit">
                  Sign out
                </button>
              </form>
            </>
          ) : (
            <>
              <NavLink href="/login">Sign in</NavLink>
              <Link
                href="/register"
                className="rounded-full bg-pine px-4 py-2 font-medium text-white"
              >
                Create an account
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link href={href} className="rounded-full px-3 py-2 text-ink/80 hover:bg-white">
      {children}
    </Link>
  );
}
