"use client";

import { useActionState } from "react";
import { decideClaim, redeemCode, type DecisionState } from "@/app/actions";

export function DecisionForm({ claimId }: { claimId: string }) {
  const [state, action, pending] = useActionState(decideClaim, null as DecisionState);
  return (
    <form action={action} className="mt-4 grid gap-3">
      <input name="claimId" type="hidden" value={claimId} />
      <label className="text-sm font-medium" htmlFor={`note-${claimId}`}>
        Note for the claimant
      </label>
      <textarea
        className="min-h-20 rounded-xl border border-line bg-card px-3 py-2"
        id={`note-${claimId}`}
        name="note"
      />
      <div className="flex flex-wrap gap-2">
        <DecisionButton pending={pending} value="approve">
          Approve
        </DecisionButton>
        <DecisionButton pending={pending} value="needs_info">
          Ask for detail
        </DecisionButton>
        <DecisionButton pending={pending} value="reject">
          Decline
        </DecisionButton>
      </div>
      <Result state={state} />
    </form>
  );
}

function DecisionButton({
  children,
  pending,
  value,
}: {
  children: React.ReactNode;
  pending: boolean;
  value: string;
}) {
  return (
    <button
      className="h-10 rounded-full border border-line bg-white px-4 text-sm font-medium disabled:opacity-60"
      disabled={pending}
      name="decision"
      type="submit"
      value={value}
    >
      {children}
    </button>
  );
}

export function RedeemForm({ claimId }: { claimId: string }) {
  const [state, action, pending] = useActionState(redeemCode, null as DecisionState);
  return (
    <form action={action} className="mt-4 flex flex-wrap items-end gap-2">
      <input name="claimId" type="hidden" value={claimId} />
      <label className="grid gap-1 text-sm font-medium">
        Collection code
        <input
          className="h-11 w-36 rounded-xl border border-line bg-card px-3 tracking-[0.2em]"
          inputMode="numeric"
          maxLength={6}
          name="code"
        />
      </label>
      <button
        className="h-11 rounded-full bg-pine px-4 text-sm font-medium text-white disabled:opacity-60"
        disabled={pending}
        type="submit"
      >
        Record handover
      </button>
      <Result state={state} />
    </form>
  );
}

function Result({ state }: { state: DecisionState }) {
  if (!state) return null;
  return (
    <div className="w-full rounded-xl bg-paper px-3 py-2 text-sm">
      <p>{state.message}</p>
      {state.code ? (
        <p className="mt-1 font-serif text-2xl tracking-[0.25em]">{state.code}</p>
      ) : null}
    </div>
  );
}
