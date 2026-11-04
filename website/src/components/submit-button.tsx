"use client";

import { useFormStatus } from "react-dom";

export function SubmitButton({ children }: { children: React.ReactNode }) {
  const { pending } = useFormStatus();
  return (
    <button
      className="h-12 rounded-full bg-pine px-5 font-medium text-white disabled:opacity-60"
      disabled={pending}
      type="submit"
    >
      {pending ? "Working…" : children}
    </button>
  );
}
