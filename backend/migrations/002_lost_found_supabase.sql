-- Applied to the Lost & Found Supabase project.
-- Snake_case so the API can read it. Privileged functions live in private.

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.universities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  short_name text not null,
  city text not null default '',
  domains text not null default '',
  accent text not null default '#285DE5',
  ref_prefix text not null,
  center_lat double precision not null,
  center_lng double precision not null,
  zoom integer not null default 16,
  retention_days integer not null default 30,
  created_at timestamptz not null default now()
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references public.universities(id) on delete cascade,
  name text not null,
  kind text not null,
  lat double precision not null,
  lng double precision not null,
  is_collection_point boolean not null default false,
  hours text
);
create index locations_university_id_idx on public.locations(university_id);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  university_id uuid not null references public.universities(id),
  email text not null unique,
  name text not null,
  role text not null default 'member' check (role in ('member', 'staff', 'admin')),
  status text not null default 'active' check (status in ('active', 'suspended')),
  department text not null default '',
  bio text not null default '',
  notifications_on boolean not null default true,
  email_verified_at timestamptz,
  created_at timestamptz not null default now()
);
create index profiles_university_id_idx on public.profiles(university_id);

create table public.institution_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  university_id uuid not null references public.universities(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'staff', 'admin')),
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  unique (user_id, university_id)
);

create table public.staff_permissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  permission text not null,
  unique (user_id, permission)
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  ref text not null unique,
  university_id uuid not null references public.universities(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('lost', 'found')),
  status text not null default 'open'
    check (status in ('open', 'reserved', 'returned', 'resolved', 'closed', 'disposed')),
  title text not null,
  description text not null,
  category text not null,
  colour text,
  location_id uuid references public.locations(id) on delete set null,
  sensitive boolean not null default false,
  custody text,
  private_details text,
  retain_until timestamptz,
  resolved_at timestamptz,
  disposal_method text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index items_feed_idx on public.items(university_id, type, status, created_at);
create index items_author_id_idx on public.items(author_id);

create sequence public.item_ref_seq;

create or replace function private.set_item_ref()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.ref is null or new.ref = '' then
    new.ref := 'LF-' || lpad(nextval('public.item_ref_seq')::text, 4, '0');
  end if;
  return new;
end;
$$;

create trigger items_ref before insert on public.items
  for each row execute function private.set_item_ref();

create table public.item_photos (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  file_path text not null,
  width integer not null default 0,
  height integer not null default 0,
  position integer not null default 0
);
create index item_photos_item_id_idx on public.item_photos(item_id);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index comments_item_id_idx on public.comments(item_id);

create table public.claims (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  claimant_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'needs_info', 'approved', 'rejected', 'withdrawn', 'completed')),
  details text not null,
  lost_where text,
  proof_path text,
  decision_note text,
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz,
  handover_code_hash text,
  handover_code_expires_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, claimant_id)
);
create index claims_claimant_id_idx on public.claims(claimant_id);
create index claims_status_idx on public.claims(status);

create table public.claim_messages (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.claims(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  flagged boolean not null default false,
  created_at timestamptz not null default now()
);
create index claim_messages_claim_id_idx on public.claim_messages(claim_id);

create table public.claim_events (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.claims(id) on delete cascade,
  title text not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);
create index claim_events_claim_id_idx on public.claim_events(claim_id);

create table public.item_handovers (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null unique references public.claims(id) on delete cascade,
  item_id uuid not null unique references public.items(id) on delete cascade,
  staff_id uuid not null references public.profiles(id),
  redeemed_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  href text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_id_idx on public.notifications(user_id, read_at);

create table public.watches (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references public.universities(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid references public.items(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index reports_university_id_idx on public.reports(university_id, status);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references public.universities(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid not null,
  summary text not null,
  created_at timestamptz not null default now()
);
create index audit_logs_university_id_idx on public.audit_logs(university_id, created_at);

insert into public.universities (slug, name, short_name, city, domains, ref_prefix, center_lat, center_lng)
values ('campus', 'Campus', 'Campus', '', '', 'LF', 51.501, -0.012)
on conflict (slug) do nothing;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger items_touch before update on public.items
  for each row execute function private.touch_updated_at();
create trigger claims_touch before update on public.claims
  for each row execute function private.touch_updated_at();

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
  insert into public.profiles (id, university_id, email, name)
  values (
    new.id,
    v_university,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'name', split_part(coalesce(new.email, 'student'), '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

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

revoke all on function private.current_profile() from public, anon;
grant execute on function private.current_profile() to authenticated;

create or replace function private.approve_claim(p_claim_id uuid, p_note text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_staff_id uuid;
  v_uni uuid;
  v_role text;
  v_item_id uuid;
  v_status text;
  v_item_uni uuid;
  v_item_status text;
  v_bytes bytea;
  v_code text;
  v_hash text;
begin
  select c.id, c.university_id, c.role into v_staff_id, v_uni, v_role
  from private.current_profile() c;
  if v_staff_id is null or v_role not in ('staff', 'admin') then
    raise exception 'not authorised';
  end if;

  select item_id, status into v_item_id, v_status
  from public.claims where id = p_claim_id for update;
  if v_item_id is null or v_status not in ('pending', 'needs_info') then
    raise exception 'claim is not waiting for review';
  end if;

  select university_id, status into v_item_uni, v_item_status
  from public.items where id = v_item_id for update;
  if v_item_uni is distinct from v_uni or v_item_status <> 'open' then
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
  where item_id = v_item_id
    and id <> p_claim_id
    and status in ('pending', 'needs_info');

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
  v_staff_id uuid;
  v_uni uuid;
  v_role text;
  v_item_id uuid;
  v_status text;
  v_hash text;
  v_stored text;
  v_expires timestamptz;
begin
  select c.id, c.university_id, c.role into v_staff_id, v_uni, v_role
  from private.current_profile() c;
  if v_staff_id is null or v_role not in ('staff', 'admin') then
    raise exception 'not authorised';
  end if;

  select item_id, status, handover_code_hash, handover_code_expires_at
  into v_item_id, v_status, v_stored, v_expires
  from public.claims where id = p_claim_id for update;

  if v_item_id is null or v_status <> 'approved' then
    raise exception 'claim is not ready for collection';
  end if;
  if not exists (
    select 1 from public.items i
    where i.id = v_item_id and i.university_id = v_uni
  ) then
    raise exception 'wrong institution';
  end if;
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
  update public.items
  set status = 'returned', resolved_at = now()
  where id = v_item_id;
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.handover', 'claim', p_claim_id, 'Completed handover with a one-time collection code.');
  return 'completed';
end;
$$;

revoke all on function private.approve_claim(uuid, text) from public, anon;
revoke all on function private.redeem_collection_code(uuid, text) from public, anon;
grant execute on function private.approve_claim(uuid, text) to authenticated;
grant execute on function private.redeem_collection_code(uuid, text) to authenticated;

create or replace function public.approve_claim(p_claim_id uuid, p_note text)
returns text
language sql
security invoker
set search_path = ''
as $$
  select private.approve_claim(p_claim_id, p_note);
$$;

create or replace function public.redeem_collection_code(p_claim_id uuid, p_code text)
returns text
language sql
security invoker
set search_path = ''
as $$
  select private.redeem_collection_code(p_claim_id, p_code);
$$;

revoke all on function public.approve_claim(uuid, text) from public, anon;
revoke all on function public.redeem_collection_code(uuid, text) from public, anon;
grant execute on function public.approve_claim(uuid, text) to authenticated;
grant execute on function public.redeem_collection_code(uuid, text) to authenticated;

alter table public.universities enable row level security;
alter table public.locations enable row level security;
alter table public.profiles enable row level security;
alter table public.institution_memberships enable row level security;
alter table public.staff_permissions enable row level security;
alter table public.items enable row level security;
alter table public.item_photos enable row level security;
alter table public.comments enable row level security;
alter table public.claims enable row level security;
alter table public.claim_messages enable row level security;
alter table public.claim_events enable row level security;
alter table public.item_handovers enable row level security;
alter table public.notifications enable row level security;
alter table public.watches enable row level security;
alter table public.reports enable row level security;
alter table public.audit_logs enable row level security;

alter table public.universities force row level security;
alter table public.locations force row level security;
alter table public.profiles force row level security;
alter table public.institution_memberships force row level security;
alter table public.staff_permissions force row level security;
alter table public.items force row level security;
alter table public.item_photos force row level security;
alter table public.comments force row level security;
alter table public.claims force row level security;
alter table public.claim_messages force row level security;
alter table public.claim_events force row level security;
alter table public.item_handovers force row level security;
alter table public.notifications force row level security;
alter table public.watches force row level security;
alter table public.reports force row level security;
alter table public.audit_logs force row level security;

revoke all on all tables in schema public from anon, authenticated;

grant select on public.universities, public.locations to authenticated;
grant select (
  id, university_id, email, name, role, status, department, bio, notifications_on, email_verified_at, created_at
) on public.profiles to authenticated;
grant select (
  id, ref, university_id, author_id, type, status, title, description, category, colour,
  location_id, sensitive, custody, retain_until, resolved_at, disposal_method, created_at, updated_at
) on public.items to authenticated;
grant insert (
  university_id, author_id, type, title, description, category, colour, location_id, sensitive, custody, private_details, retain_until
) on public.items to authenticated;
grant select on public.item_photos, public.comments, public.claim_events, public.notifications, public.watches to authenticated;
grant insert (item_id, author_id, body) on public.comments to authenticated;
grant insert (item_id, claimant_id, details, lost_where, proof_path) on public.claims to authenticated;
grant select (
  id, item_id, claimant_id, status, details, lost_where, decision_note, decided_by, decided_at,
  handover_code_expires_at, completed_at, created_at, updated_at
) on public.claims to authenticated;

create policy universities_read on public.universities
  for select to authenticated
  using (id = (select university_id from private.current_profile()));

create policy locations_read on public.locations
  for select to authenticated
  using (university_id = (select university_id from private.current_profile()));

create policy profiles_read on public.profiles
  for select to authenticated
  using (university_id = (select university_id from private.current_profile()));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from private.current_profile()));

grant update (name, department, bio, notifications_on) on public.profiles to authenticated;

create policy items_read on public.items
  for select to authenticated
  using (university_id = (select university_id from private.current_profile()));

create policy items_insert on public.items
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and university_id = (select university_id from private.current_profile())
  );

create policy comments_read on public.comments
  for select to authenticated
  using (
    hidden = false
    and exists (
      select 1 from public.items i
      where i.id = comments.item_id
        and i.university_id = (select university_id from private.current_profile())
    )
  );

create policy comments_insert on public.comments
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.items i
      where i.id = item_id
        and i.university_id = (select university_id from private.current_profile())
    )
  );

create policy claims_insert on public.claims
  for insert to authenticated
  with check (
    claimant_id = auth.uid()
    and exists (
      select 1 from public.items i
      where i.id = item_id
        and i.university_id = (select university_id from private.current_profile())
        and i.status = 'open'
        and i.type = 'found'
        and i.author_id <> auth.uid()
    )
  );

create policy claims_read on public.claims
  for select to authenticated
  using (
    claimant_id = auth.uid()
    or exists (
      select 1 from public.items i
      where i.id = claims.item_id
        and i.university_id = (select university_id from private.current_profile())
        and (select role from private.current_profile()) in ('staff', 'admin')
    )
  );

create policy notifications_read on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

create policy watches_own on public.watches
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant insert, delete on public.watches to authenticated;

insert into storage.buckets (id, name, public)
values ('item-photos', 'item-photos', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('claim-evidence', 'claim-evidence', false)
on conflict (id) do nothing;

create policy item_photos_read on storage.objects
  for select to authenticated
  using (bucket_id = 'item-photos');

create policy item_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy claim_evidence_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'claim-evidence'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or (select role from private.current_profile()) in ('staff', 'admin')
    )
  );

create policy claim_evidence_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'claim-evidence'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
