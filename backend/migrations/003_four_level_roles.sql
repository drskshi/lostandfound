-- Four-level roles on the existing Lost & Found tables.
-- Authority is role_assignments, written only by private functions.
-- profiles.role is a display cache. Clients cannot change it.

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.universities(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (institution_id, name)
);
create index if not exists departments_institution_id_idx on public.departments(institution_id);

alter table public.items add column if not exists department_id uuid references public.departments(id) on delete set null;
create index if not exists items_department_id_idx on public.items(department_id);

alter table public.reports add column if not exists department_id uuid references public.departments(id) on delete set null;

create table if not exists public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('superadmin', 'admin', 'subadmin', 'student')),
  institution_id uuid references public.universities(id) on delete cascade,
  department_id uuid references public.departments(id) on delete cascade,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (
    (role = 'superadmin' and institution_id is null and department_id is null)
    or (role = 'admin' and institution_id is not null and department_id is null)
    or (role = 'subadmin' and institution_id is not null and department_id is not null)
    or (role = 'student' and institution_id is not null and department_id is null)
  )
);
create unique index if not exists role_assignments_superadmin_uidx
  on public.role_assignments(user_id) where role = 'superadmin';
create unique index if not exists role_assignments_admin_uidx
  on public.role_assignments(user_id, institution_id) where role = 'admin';
create unique index if not exists role_assignments_subadmin_uidx
  on public.role_assignments(user_id, department_id) where role = 'subadmin';
create unique index if not exists role_assignments_student_uidx
  on public.role_assignments(user_id, institution_id) where role = 'student';

create or replace view public.department_assignments
with (security_invoker = true) as
select id, user_id, institution_id, department_id, granted_by, created_at
from public.role_assignments
where role = 'subadmin';

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%role%'
  loop
    execute format('alter table public.profiles drop constraint %I', constraint_name);
  end loop;
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'public.institution_memberships'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%role%'
  loop
    execute format('alter table public.institution_memberships drop constraint %I', constraint_name);
  end loop;
end $$;

alter table public.profiles alter column role set default 'student';
alter table public.institution_memberships alter column role set default 'student';
update public.profiles
set role = case role
  when 'member' then 'student'
  when 'staff' then 'admin'
  when 'admin' then 'admin'
  else role
end
where role in ('member', 'staff', 'admin');
update public.institution_memberships
set role = case role
  when 'member' then 'student'
  when 'staff' then 'admin'
  when 'admin' then 'admin'
  else role
end
where role in ('member', 'staff', 'admin');

alter table public.profiles add constraint profiles_role_check
  check (role in ('superadmin', 'admin', 'subadmin', 'student'));
alter table public.institution_memberships add constraint institution_memberships_role_check
  check (role in ('superadmin', 'admin', 'subadmin', 'student'));

insert into public.role_assignments (user_id, role, institution_id)
select p.id,
  case p.role
    when 'superadmin' then 'superadmin'
    when 'admin' then 'admin'
    when 'subadmin' then 'student'
    else 'student'
  end,
  case when p.role = 'superadmin' then null else p.university_id end
from public.profiles p
where not exists (
  select 1 from public.role_assignments ra where ra.user_id = p.id
);

create or replace function private.protect_profile_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role is distinct from old.role and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'role cannot be self-assigned';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
  before update of role on public.profiles
  for each row execute function private.protect_profile_role();

create or replace function private.assignment_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role = 'subadmin' and not exists (
    select 1 from public.departments d
    where d.id = new.department_id and d.institution_id = new.institution_id
  ) then
    raise exception 'department is not in that institution';
  end if;
  return new;
end;
$$;

drop trigger if exists role_assignments_guard on public.role_assignments;
create trigger role_assignments_guard
  before insert or update on public.role_assignments
  for each row execute function private.assignment_guard();

create or replace function private.sync_profile_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := coalesce(new.user_id, old.user_id);
  v_role text;
begin
  select ra.role into v_role
  from public.role_assignments ra
  where ra.user_id = v_user
  order by case ra.role
    when 'superadmin' then 1
    when 'admin' then 2
    when 'subadmin' then 3
    else 4
  end
  limit 1;
  update public.profiles
  set role = coalesce(v_role, 'student')
  where id = v_user;
  return coalesce(new, old);
end;
$$;

drop trigger if exists role_assignments_sync on public.role_assignments;
create trigger role_assignments_sync
  after insert or update or delete on public.role_assignments
  for each row execute function private.sync_profile_role();

create or replace function private.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.role_assignments ra
    where ra.user_id = auth.uid() and ra.role = 'superadmin'
  );
$$;

create or replace function private.is_institution_admin(p_institution uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_superadmin() or exists (
    select 1 from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role = 'admin'
      and ra.institution_id = p_institution
  );
$$;

create or replace function private.is_subadmin_of(p_department uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.role_assignments ra
    where ra.user_id = auth.uid()
      and ra.role = 'subadmin'
      and ra.department_id = p_department
  );
$$;

create or replace function private.is_member_of(p_institution uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_superadmin() or exists (
    select 1 from public.role_assignments ra
    where ra.user_id = auth.uid() and ra.institution_id = p_institution
  );
$$;

create or replace function private.can_review_claim(p_claim_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.claims c
    join public.items i on i.id = c.item_id
    where c.id = p_claim_id
      and (
        private.is_superadmin()
        or private.is_institution_admin(i.university_id)
        or (i.department_id is not null and private.is_subadmin_of(i.department_id))
      )
  );
$$;

create or replace function private.can_read_evidence_name(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner text := split_part(p_name, '/', 1);
  v_claim text := split_part(p_name, '/', 2);
begin
  if auth.uid() is not null and v_owner = auth.uid()::text then
    return true;
  end if;
  if v_claim ~* '^[0-9a-f-]{36}$' and private.can_review_claim(v_claim::uuid) then
    return true;
  end if;
  return false;
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_university uuid;
begin
  select id into v_university from public.universities where slug = 'campus' limit 1;
  insert into public.profiles (id, university_id, email, name, role)
  values (
    new.id,
    v_university,
    coalesce(new.email, ''),
    coalesce(split_part(coalesce(new.email, 'student'), '@', 1), 'student'),
    'student'
  )
  on conflict (id) do nothing;
  insert into public.role_assignments (user_id, role, institution_id)
  select new.id, 'student', v_university
  where not exists (
    select 1 from public.role_assignments ra
    where ra.user_id = new.id and ra.role = 'student' and ra.institution_id = v_university
  );
  insert into public.institution_memberships (user_id, university_id, role, status)
  values (new.id, v_university, 'student', 'active')
  on conflict (user_id, university_id) do nothing;
  return new;
end;
$$;

create or replace function private.current_profile()
returns table (id uuid, university_id uuid, role text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.university_id, p.role
  from public.profiles p
  where p.id = auth.uid() and p.status = 'active'
  limit 1;
$$;

create or replace function private.grant_role(
  p_user_id uuid,
  p_role text,
  p_institution_id uuid,
  p_department_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if p_role not in ('superadmin', 'admin', 'subadmin', 'student') then
    raise exception 'unknown role';
  end if;
  if private.is_superadmin() then
    null;
  elsif p_role in ('student', 'subadmin') and private.is_institution_admin(p_institution_id) then
    null;
  else
    raise exception 'not authorised';
  end if;
  if p_role = 'superadmin' and not private.is_superadmin() then
    raise exception 'not authorised';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'profile missing';
  end if;

  insert into public.role_assignments (user_id, role, institution_id, department_id, granted_by)
  values (p_user_id, p_role, p_institution_id, p_department_id, v_actor);

  if p_institution_id is not null then
    insert into public.institution_memberships (user_id, university_id, role, status)
    values (p_user_id, p_institution_id, p_role, 'active')
    on conflict (user_id, university_id) do update
      set role = excluded.role;
  end if;

  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (
    coalesce(p_institution_id, (select university_id from public.profiles where id = v_actor)),
    v_actor,
    'role.grant',
    'profile',
    p_user_id,
    'Granted ' || p_role
  );
end;
$$;

create or replace function private.approve_claim(p_claim_id uuid, p_note text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_staff_id uuid := auth.uid();
  v_uni uuid;
  v_item_id uuid;
  v_status text;
  v_item_status text;
  v_bytes bytea;
  v_code text;
  v_hash text;
begin
  if not private.can_review_claim(p_claim_id) then
    raise exception 'not authorised';
  end if;
  select item_id, status into v_item_id, v_status
  from public.claims where id = p_claim_id for update;
  if v_item_id is null or v_status not in ('pending', 'needs_info') then
    raise exception 'claim is not waiting for review';
  end if;
  select university_id, status into v_uni, v_item_status
  from public.items where id = v_item_id for update;
  if v_item_status <> 'open' then
    raise exception 'item cannot be approved';
  end if;
  if exists (
    select 1 from public.claims
    where item_id = v_item_id and status in ('approved', 'completed')
  ) then
    raise exception 'another claim is already approved';
  end if;

  v_bytes := gen_random_bytes(3);
  v_code := lpad(((get_byte(v_bytes, 0) * 65536 + get_byte(v_bytes, 1) * 256 + get_byte(v_bytes, 2)) % 1000000)::text, 6, '0');
  v_hash := encode(digest(p_claim_id::text || ':' || v_code, 'sha256'), 'hex');

  update public.claims
  set status = 'approved',
      decision_note = p_note,
      decided_by = v_staff_id,
      decided_at = now(),
      handover_code_hash = v_hash,
      handover_code_expires_at = now() + interval '7 days'
  where id = p_claim_id;

  update public.claims
  set status = 'rejected',
      decision_note = 'Another claim was approved for this item.',
      decided_by = v_staff_id,
      decided_at = now()
  where item_id = v_item_id and id <> p_claim_id and status in ('pending', 'needs_info');

  update public.items set status = 'reserved' where id = v_item_id;
  insert into public.claim_events (claim_id, title, detail)
  values (p_claim_id, 'Approved', coalesce(p_note, ''));
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.approve', 'claim', p_claim_id, 'Approved a claim and issued a one-time collection code.');
  return v_code;
end;
$$;

create or replace function private.redeem_collection_code(p_claim_id uuid, p_code text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_staff_id uuid := auth.uid();
  v_uni uuid;
  v_item_id uuid;
  v_status text;
  v_hash text;
  v_stored text;
  v_expires timestamptz;
begin
  if not private.can_review_claim(p_claim_id) then
    raise exception 'not authorised';
  end if;
  select item_id, status, handover_code_hash, handover_code_expires_at
  into v_item_id, v_status, v_stored, v_expires
  from public.claims where id = p_claim_id for update;
  if v_item_id is null or v_status <> 'approved' then
    raise exception 'claim is not ready for collection';
  end if;
  select university_id into v_uni from public.items where id = v_item_id;
  if v_expires is null or v_expires < now() then
    raise exception 'collection code expired';
  end if;
  if exists (
    select 1 from public.item_handovers h
    where h.claim_id = p_claim_id or h.item_id = v_item_id
  ) then
    raise exception 'collection code already used';
  end if;
  v_hash := encode(digest(p_claim_id::text || ':' || p_code, 'sha256'), 'hex');
  if v_stored is distinct from v_hash then
    raise exception 'collection code does not match';
  end if;
  insert into public.item_handovers (claim_id, item_id, staff_id)
  values (p_claim_id, v_item_id, v_staff_id);
  update public.claims
  set status = 'completed', completed_at = now(), handover_code_hash = null
  where id = p_claim_id;
  update public.items set status = 'returned', resolved_at = now() where id = v_item_id;
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.handover', 'claim', p_claim_id, 'Completed handover with a one-time collection code.');
  return 'completed';
end;
$$;

create or replace function private.claim_evidence_path(p_claim_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_path text;
begin
  select claimant_id, proof_path into v_owner, v_path
  from public.claims where id = p_claim_id;
  if v_owner is null then
    return null;
  end if;
  if v_owner = auth.uid() or private.can_review_claim(p_claim_id) then
    return v_path;
  end if;
  return null;
end;
$$;

create or replace function private.bootstrap_superadmin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.role_assignments where role = 'superadmin') then
    raise exception 'a superadmin already exists';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id and status = 'active') then
    raise exception 'profile missing';
  end if;
  insert into public.role_assignments (user_id, role, granted_by)
  values (p_user_id, 'superadmin', p_user_id);
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (
    (select university_id from public.profiles where id = p_user_id),
    p_user_id,
    'role.bootstrap',
    'profile',
    p_user_id,
    'Provisioned the first superadmin.'
  );
end;
$$;

revoke all on function private.bootstrap_superadmin(uuid) from public, anon, authenticated;
revoke all on function private.grant_role(uuid, text, uuid, uuid) from public, anon;
revoke all on function private.claim_evidence_path(uuid) from public, anon;
revoke all on function private.is_superadmin() from public, anon;
revoke all on function private.is_institution_admin(uuid) from public, anon;
revoke all on function private.is_subadmin_of(uuid) from public, anon;
revoke all on function private.is_member_of(uuid) from public, anon;
revoke all on function private.can_review_claim(uuid) from public, anon;
revoke all on function private.can_read_evidence_name(text) from public, anon;
grant execute on function private.grant_role(uuid, text, uuid, uuid) to authenticated;
grant execute on function private.claim_evidence_path(uuid) to authenticated;
grant execute on function private.is_superadmin() to authenticated;
grant execute on function private.is_institution_admin(uuid) to authenticated;
grant execute on function private.is_subadmin_of(uuid) to authenticated;
grant execute on function private.is_member_of(uuid) to authenticated;
grant execute on function private.can_review_claim(uuid) to authenticated;
grant execute on function private.can_read_evidence_name(text) to authenticated;

create or replace function public.grant_role(
  p_user_id uuid,
  p_role text,
  p_institution_id uuid default null,
  p_department_id uuid default null
) returns void
language sql
security invoker
set search_path = ''
as $$
  select private.grant_role(p_user_id, p_role, p_institution_id, p_department_id);
$$;

create or replace function public.claim_evidence_path(p_claim_id uuid)
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select private.claim_evidence_path(p_claim_id);
$$;

revoke all on function public.grant_role(uuid, text, uuid, uuid) from public, anon;
revoke all on function public.claim_evidence_path(uuid) from public, anon;
grant execute on function public.grant_role(uuid, text, uuid, uuid) to authenticated;
grant execute on function public.claim_evidence_path(uuid) to authenticated;

alter table public.departments enable row level security;
alter table public.departments force row level security;
alter table public.role_assignments enable row level security;
alter table public.role_assignments force row level security;
revoke all on public.departments, public.role_assignments from anon, authenticated;
grant select on public.departments, public.role_assignments, public.department_assignments to authenticated;
grant insert (department_id) on public.items to authenticated;
grant insert (institution_id, name) on public.departments to authenticated;

drop policy if exists universities_read on public.universities;
create policy universities_read on public.universities
  for select to authenticated
  using (private.is_superadmin() or private.is_member_of(id));

drop policy if exists locations_read on public.locations;
create policy locations_read on public.locations
  for select to authenticated
  using (private.is_superadmin() or private.is_member_of(university_id));

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to authenticated
  using (private.is_superadmin() or private.is_member_of(university_id) or id = auth.uid());

drop policy if exists items_read on public.items;
create policy items_read on public.items
  for select to authenticated
  using (private.is_superadmin() or private.is_member_of(university_id));

drop policy if exists items_insert on public.items;
create policy items_insert on public.items
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and (private.is_superadmin() or private.is_member_of(university_id))
    and (
      department_id is null
      or private.is_institution_admin(university_id)
      or private.is_subadmin_of(department_id)
      or private.is_superadmin()
    )
  );

drop policy if exists claims_read on public.claims;
create policy claims_read on public.claims
  for select to authenticated
  using (
    claimant_id = auth.uid()
    or private.can_review_claim(id)
  );

drop policy if exists departments_select on public.departments;
create policy departments_select on public.departments
  for select to authenticated
  using (private.is_superadmin() or private.is_member_of(institution_id));

drop policy if exists departments_insert on public.departments;
create policy departments_insert on public.departments
  for insert to authenticated
  with check (private.is_institution_admin(institution_id));

drop policy if exists role_assignments_select on public.role_assignments;
create policy role_assignments_select on public.role_assignments
  for select to authenticated
  using (
    user_id = auth.uid()
    or private.is_superadmin()
    or (institution_id is not null and private.is_institution_admin(institution_id))
  );

drop policy if exists claim_evidence_read on storage.objects;
create policy claim_evidence_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'claim-evidence'
    and private.can_read_evidence_name(name)
  );

create or replace function private.item_department_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.department_id is not null and not exists (
    select 1 from public.departments d
    where d.id = new.department_id and d.institution_id = new.university_id
  ) then
    raise exception 'department is not in that institution';
  end if;
  return new;
end;
$$;

drop trigger if exists items_department_guard on public.items;
create trigger items_department_guard
  before insert or update of department_id, university_id on public.items
  for each row execute function private.item_department_guard();
