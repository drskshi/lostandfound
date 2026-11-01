-- Additive client workflow. Does not drop tables or weaken existing checks.
-- Photo rows, claim events, and read receipts become readable only to the
-- people the existing role helpers already allow. Claim decisions stay in
-- private security-definer functions.

grant insert (item_id, file_path, width, height, position)
  on public.item_photos to authenticated;

create policy item_photos_select on public.item_photos
  for select to authenticated
  using (
    exists (
      select 1 from public.items i
      where i.id = item_photos.item_id
        and (private.is_superadmin() or private.is_member_of(i.university_id))
    )
  );

create policy item_photos_insert on public.item_photos
  for insert to authenticated
  with check (
    exists (
      select 1 from public.items i
      where i.id = item_photos.item_id
        and i.author_id = auth.uid()
    )
  );

create policy claim_events_select on public.claim_events
  for select to authenticated
  using (
    exists (
      select 1 from public.claims c
      where c.id = claim_events.claim_id
        and (
          c.claimant_id = auth.uid()
          or private.can_review_claim(c.id)
        )
    )
  );

grant update (read_at) on public.notifications to authenticated;

create policy notifications_update_own on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

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
  v_claimant uuid;
  v_status text;
  v_item_status text;
  v_bytes bytea;
  v_code text;
  v_hash text;
begin
  if not private.can_review_claim(p_claim_id) then
    raise exception 'not authorised';
  end if;
  select item_id, claimant_id, status into v_item_id, v_claimant, v_status
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
  insert into public.notifications (user_id, kind, title, body, href)
  values (
    v_claimant,
    'ready_for_collection',
    'Your claim was approved',
    'Your collection code is ' || v_code || '. It expires in 7 days and works once.',
    '/claims/' || p_claim_id::text
  );
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.approve', 'claim', p_claim_id, 'Approved a claim and issued a one-time collection code.');
  return v_code;
end;
$$;

create or replace function private.reject_claim(p_claim_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff_id uuid := auth.uid();
  v_uni uuid;
  v_item_id uuid;
  v_claimant uuid;
  v_status text;
begin
  if not private.can_review_claim(p_claim_id) then
    raise exception 'not authorised';
  end if;
  if coalesce(length(trim(p_note)), 0) < 3 then
    raise exception 'a decision note is required';
  end if;
  select item_id, claimant_id, status into v_item_id, v_claimant, v_status
  from public.claims where id = p_claim_id for update;
  if v_item_id is null or v_status not in ('pending', 'needs_info') then
    raise exception 'claim is not waiting for review';
  end if;
  select university_id into v_uni from public.items where id = v_item_id;
  update public.claims
  set status = 'rejected',
      decision_note = trim(p_note),
      decided_by = v_staff_id,
      decided_at = now()
  where id = p_claim_id;
  insert into public.claim_events (claim_id, title, detail)
  values (p_claim_id, 'Not approved', trim(p_note));
  insert into public.notifications (user_id, kind, title, body, href)
  values (
    v_claimant,
    'claim_rejected',
    'Your claim was not approved',
    trim(p_note),
    '/claims/' || p_claim_id::text
  );
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.reject', 'claim', p_claim_id, 'Rejected a claim.');
end;
$$;

create or replace function private.request_claim_info(p_claim_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff_id uuid := auth.uid();
  v_uni uuid;
  v_item_id uuid;
  v_claimant uuid;
  v_status text;
begin
  if not private.can_review_claim(p_claim_id) then
    raise exception 'not authorised';
  end if;
  if coalesce(length(trim(p_note)), 0) < 3 then
    raise exception 'a decision note is required';
  end if;
  select item_id, claimant_id, status into v_item_id, v_claimant, v_status
  from public.claims where id = p_claim_id for update;
  if v_item_id is null or v_status not in ('pending', 'needs_info') then
    raise exception 'claim is not waiting for review';
  end if;
  select university_id into v_uni from public.items where id = v_item_id;
  update public.claims
  set status = 'needs_info',
      decision_note = trim(p_note),
      decided_by = v_staff_id,
      decided_at = now()
  where id = p_claim_id;
  insert into public.claim_events (claim_id, title, detail)
  values (p_claim_id, 'More information requested', trim(p_note));
  insert into public.notifications (user_id, kind, title, body, href)
  values (
    v_claimant,
    'claim_evidence',
    'More information is needed',
    trim(p_note),
    '/claims/' || p_claim_id::text
  );
  insert into public.audit_logs (university_id, actor_id, action, target_type, target_id, summary)
  values (v_uni, v_staff_id, 'claim.evidence', 'claim', p_claim_id, 'Requested more claim information.');
end;
$$;

revoke all on function private.reject_claim(uuid, text) from public, anon;
revoke all on function private.request_claim_info(uuid, text) from public, anon;

create or replace function public.reject_claim(p_claim_id uuid, p_note text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.reject_claim(p_claim_id, p_note);
$$;

create or replace function public.request_claim_info(p_claim_id uuid, p_note text)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.request_claim_info(p_claim_id, p_note);
$$;

revoke all on function public.reject_claim(uuid, text) from public, anon;
revoke all on function public.request_claim_info(uuid, text) from public, anon;
grant execute on function public.reject_claim(uuid, text) to authenticated;
grant execute on function public.request_claim_info(uuid, text) to authenticated;

update public.universities
set name = 'Northbridge College',
    short_name = 'Northbridge',
    city = 'London'
where slug = 'campus' and name = 'Campus';

insert into public.departments (institution_id, name)
select u.id, dept.name
from public.universities u
cross join (values ('Computing'), ('Design'), ('Student services')) as dept(name)
where u.slug = 'campus'
  and not exists (
    select 1 from public.departments existing
    where existing.institution_id = u.id and existing.name = dept.name
  );

insert into public.locations (university_id, name, kind, lat, lng, is_collection_point, hours)
select u.id, place.name, place.kind, place.lat, place.lng, place.collection, place.hours
from public.universities u
cross join (
  values
    ('Library', 'building', 51.5014, -0.0122, false, '08:00–20:00'),
    ('Student hub', 'building', 51.5018, -0.0114, false, '09:00–18:00'),
    ('Reception desk', 'desk', 51.5010, -0.0128, true, '09:00–17:00')
) as place(name, kind, lat, lng, collection, hours)
where u.slug = 'campus'
  and not exists (
    select 1 from public.locations existing
    where existing.university_id = u.id
  );
