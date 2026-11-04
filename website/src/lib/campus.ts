import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export const roles = ["superadmin", "admin", "subadmin", "student"] as const;
export type CampusRole = (typeof roles)[number];

export type Profile = {
  id: string;
  university_id: string;
  email: string;
  name: string;
  role: CampusRole;
  status: string;
  department: string;
};

const roleLabels: Record<CampusRole, string> = {
  superadmin: "Superadmin",
  admin: "Admin",
  subadmin: "Sub-admin",
  student: "Student",
};

export function parseRole(value: string | null | undefined): CampusRole {
  if (value === "superadmin" || value === "admin" || value === "subadmin") {
    return value;
  }
  return "student";
}

export function roleLabel(role: CampusRole) {
  return roleLabels[role];
}

export function isStaff(role: CampusRole) {
  return role !== "student";
}

export function readableError(message: string) {
  const lower = message.toLowerCase();
  if (lower.includes("invalid login") || lower.includes("invalid credentials")) {
    return "That email and password don't match.";
  }
  if (lower.includes("already registered") || lower.includes("already been registered")) {
    return "There is already an account with that email. Try signing in.";
  }
  if (lower.includes("email not confirmed")) {
    return "Confirm your email before signing in.";
  }
  if (
    lower.includes("permission") ||
    lower.includes("not authorised") ||
    lower.includes("not authorized") ||
    lower.includes("row-level") ||
    lower.includes("42501")
  ) {
    return "You don't have permission for that.";
  }
  if (message.length > 180 || message.includes("eyJ") || message.includes("Bearer")) {
    return "That could not be saved.";
  }
  return message || "That could not be saved.";
}

export function formatWhen(value: string) {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function statusLabel(status: string) {
  if (status === "needs_info") return "Needs detail";
  return status.slice(0, 1).toUpperCase() + status.slice(1);
}

export async function currentProfile(): Promise<Profile | null> {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) {
    return null;
  }
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();
  const id = data?.claims?.sub;
  if (error || !id) return null;

  const { data: row } = await supabase
    .from("profiles")
    .select("id, university_id, email, name, role, status, department")
    .eq("id", id)
    .maybeSingle();

  if (!row || row.status === "suspended") {
    if (row?.status === "suspended") await supabase.auth.signOut();
    return null;
  }

  return {
    id: row.id,
    university_id: row.university_id,
    email: row.email,
    name: row.name,
    role: parseRole(row.role),
    status: row.status,
    department: row.department ?? "",
  };
}

export async function requireProfile() {
  const profile = await currentProfile();
  if (!profile) redirect("/login");
  return profile;
}
