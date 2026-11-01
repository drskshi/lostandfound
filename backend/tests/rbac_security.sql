-- Leaves one report row in public.rbac_probe_report and removes the probe accounts.
do $rbac$
declare
  v_instance uuid;
  v_campus uuid;
  v_other uuid;
  v_dept_a uuid := gen_random_uuid();
  v_dept_b uuid := gen_random_uuid();
  v_dept_other uuid := gen_random_uuid();
  v_student_a uuid := gen_random_uuid();
  v_student_b uuid := gen_random_uuid();
  v_student_other uuid := gen_random_uuid();
  v_admin_campus uuid := gen_random_uuid();
  v_admin_other uuid := gen_random_uuid();
  v_sub_a uuid := gen_random_uuid();
  v_sub_b uuid := gen_random_uuid();
  v_sneaky uuid := gen_random_uuid();
  v_item_evidence uuid := gen_random_uuid();
  v_item_code uuid := gen_random_uuid();
  v_item_expired uuid := gen_random_uuid();
  v_item_used uuid := gen_random_uuid();
  v_item_sub uuid := gen_random_uuid();
  v_item_other uuid := gen_random_uuid();
  v_claim_evidence uuid := gen_random_uuid();
  v_claim_code uuid := gen_random_uuid();
  v_claim_expired uuid := gen_random_uuid();
  v_claim_used uuid := gen_random_uuid();
  v_claim_sub uuid := gen_random_uuid();
  v_report text := '';
  v_signup boolean := true;
  v_code text;
  v_path text;
  v_n int;
  v_ok boolean;
begin
  select id into v_campus from public.universities where slug = 'campus' limit 1;
  if v_campus is null then
    raise exception 'RBAC_REPORT campus=BLOCKED';
  end if;
  select id into v_instance from auth.instances limit 1;
  if v_instance is null then
    v_instance := '00000000-0000-0000-0000-000000000000';
  end if;

  insert into public.universities (id, slug, name, short_name, ref_prefix, center_lat, center_lng)
  values (gen_random_uuid(), 'rbac-other', 'RBAC Other', 'Other', 'RO', 0, 0)
  returning id into v_other;

  insert into public.departments (id, institution_id, name) values
    (v_dept_a, v_campus, 'RBAC Arts'),
    (v_dept_b, v_campus, 'RBAC Science'),
    (v_dept_other, v_other, 'RBAC Remote');

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values
    (v_instance, v_student_a, 'authenticated', 'authenticated', 'rbac-student-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_student_b, 'authenticated', 'authenticated', 'rbac-student-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_student_other, 'authenticated', 'authenticated', 'rbac-student-other@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_admin_campus, 'authenticated', 'authenticated', 'rbac-admin-campus@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_admin_other, 'authenticated', 'authenticated', 'rbac-admin-other@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_sub_a, 'authenticated', 'authenticated', 'rbac-sub-a@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_sub_b, 'authenticated', 'authenticated', 'rbac-sub-b@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    (v_instance, v_sneaky, 'authenticated', 'authenticated', 'rbac-sneaky@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"role":"superadmin"}', now(), now(), '', '', '', '');

  if (select role from public.profiles where id = v_sneaky) is distinct from 'student'
     or exists (
       select 1 from public.role_assignments
       where user_id = v_sneaky and role <> 'student'
     ) then
    v_signup := false;
  end if;

  delete from public.role_assignments where user_id in (v_admin_other, v_student_other);
  delete from public.institution_memberships where user_id in (v_admin_other, v_student_other);
  update public.profiles set university_id = v_other where id in (v_admin_other, v_student_other);
  insert into public.role_assignments (user_id, role, institution_id, granted_by) values
    (v_admin_other, 'admin', v_other, v_admin_other),
    (v_student_other, 'student', v_other, v_admin_other),
    (v_admin_campus, 'admin', v_campus, v_admin_campus);
  insert into public.role_assignments (user_id, role, institution_id, department_id, granted_by) values
    (v_sub_a, 'subadmin', v_campus, v_dept_a, v_admin_campus),
    (v_sub_b, 'subadmin', v_campus, v_dept_b, v_admin_campus);
  insert into public.institution_memberships (user_id, university_id, role) values
    (v_admin_other, v_other, 'admin'),
    (v_student_other, v_other, 'student')
  on conflict (user_id, university_id) do update set role = excluded.role;

  insert into public.items (id, ref, university_id, author_id, type, title, description, category, department_id) values
    (v_item_evidence, 'RBAC-EVID', v_campus, v_student_a, 'found', 'Evidence badge', 'probe', 'other', v_dept_a),
    (v_item_code, 'RBAC-CODE', v_campus, v_student_a, 'found', 'Code badge', 'probe', 'other', v_dept_a),
    (v_item_expired, 'RBAC-EXP', v_campus, v_student_a, 'found', 'Expired badge', 'probe', 'other', v_dept_a),
    (v_item_used, 'RBAC-USED', v_campus, v_student_a, 'found', 'Used badge', 'probe', 'other', v_dept_a),
    (v_item_sub, 'RBAC-SUB', v_campus, v_student_a, 'found', 'Department badge', 'probe', 'other', v_dept_a),
    (v_item_other, 'RBAC-OTHER', v_other, v_student_other, 'found', 'Other badge', 'probe', 'other', v_dept_other);

  insert into public.claims (id, item_id, claimant_id, details, proof_path) values
    (v_claim_evidence, v_item_evidence, v_student_a, 'mine', 'secret-evidence'),
    (v_claim_code, v_item_code, v_student_a, 'code', 'secret-code'),
    (v_claim_sub, v_item_sub, v_student_a, 'department', 'secret-sub');
  insert into public.claims (
    id, item_id, claimant_id, status, details, proof_path, handover_code_hash, handover_code_expires_at
  ) values (
    v_claim_expired, v_item_expired, v_student_a, 'approved', 'expired', 'secret-expired',
    encode(extensions.digest(v_claim_expired::text || ':111111', 'sha256'), 'hex'),
    now() - interval '1 minute'
  ), (
    v_claim_used, v_item_used, v_student_a, 'approved', 'used', 'secret-used',
    encode(extensions.digest(v_claim_used::text || ':222222', 'sha256'), 'hex'),
    now() + interval '7 days'
  );
  insert into public.item_handovers (claim_id, item_id, staff_id)
  values (v_claim_used, v_item_used, v_admin_campus);

  perform set_config('request.jwt.claim.sub', v_student_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_student_a)::text, true);
  execute 'set local role authenticated';
  if auth.uid() is distinct from v_student_a then
    raise exception 'RBAC_REPORT auth.uid=BLOCKED %', coalesce(auth.uid()::text, 'null');
  end if;

  begin
    update public.profiles set role = 'superadmin' where id = v_student_a;
    v_signup := false;
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlerrm ilike '%role cannot be self-assigned%' or sqlerrm ilike '%permission denied%' then
        null;
      else
        v_signup := false;
      end if;
  end;
  begin
    perform public.grant_role(v_student_a, 'superadmin', null, null);
    v_signup := false;
  exception
    when others then
      if sqlerrm not ilike '%not authorised%' then
        v_signup := false;
      end if;
  end;
  v_report := v_report || 'Students cannot become admins through signup.=' || case when v_signup then 'PASS' else 'FAIL' end || chr(10);

  perform set_config('request.jwt.claim.sub', v_student_b::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_student_b)::text, true);
  select count(*) into v_n from public.claims where id = v_claim_evidence;
  select public.claim_evidence_path(v_claim_evidence) into v_path;
  v_ok := v_n = 0 and v_path is null;
  perform set_config('request.jwt.claim.sub', v_student_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_student_a)::text, true);
  select public.claim_evidence_path(v_claim_evidence) into v_path;
  v_ok := v_ok and v_path = 'secret-evidence';
  begin
    perform proof_path from public.claims where id = v_claim_evidence;
    v_ok := false;
  exception
    when insufficient_privilege then
      null;
    when others then
      v_ok := false;
  end;
  v_report := v_report || 'Students cannot access other users'' private claim evidence.=' || case when v_ok then 'PASS' else 'FAIL' end || chr(10);

  perform set_config('request.jwt.claim.sub', v_admin_campus::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin_campus)::text, true);
  select count(*) into v_n from public.items where id = v_item_other;
  v_ok := v_n = 0;
  begin
    update public.universities set name = 'Hacked' where id = v_other;
    get diagnostics v_n = row_count;
    if v_n <> 0 then
      v_ok := false;
    end if;
  exception
    when insufficient_privilege then
      null;
    when others then
      v_ok := false;
  end;
  begin
    perform public.grant_role(v_student_other, 'student', v_other, null);
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%not authorised%' then
        v_ok := false;
      end if;
  end;
  v_report := v_report || 'Admins cannot access another institution.=' || case when v_ok then 'PASS' else 'FAIL' end || chr(10);

  perform set_config('request.jwt.claim.sub', v_sub_b::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_sub_b)::text, true);
  select count(*) into v_n from public.claims where id = v_claim_evidence;
  select public.claim_evidence_path(v_claim_evidence) into v_path;
  v_ok := v_n = 0 and v_path is null;
  begin
    perform public.approve_claim(v_claim_sub, 'no');
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%not authorised%' then
        v_ok := false;
      end if;
  end;
  perform set_config('request.jwt.claim.sub', v_sub_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_sub_a)::text, true);
  select count(*) into v_n from public.claims where id = v_claim_evidence;
  if v_ok and v_n = 1 then
    v_report := v_report || 'Sub-admins cannot access another department.=PASS' || chr(10);
  else
    v_report := v_report || 'Sub-admins cannot access another department.=FAIL' || chr(10);
  end if;

  v_ok := true;
  perform set_config('request.jwt.claim.sub', v_student_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_student_a)::text, true);
  begin
    perform public.approve_claim(v_claim_code, 'student');
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%not authorised%' then v_ok := false; end if;
  end;
  perform set_config('request.jwt.claim.sub', v_admin_other::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin_other)::text, true);
  begin
    perform public.approve_claim(v_claim_code, 'other');
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%not authorised%' then v_ok := false; end if;
  end;
  perform set_config('request.jwt.claim.sub', v_sub_a::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_sub_a)::text, true);
  begin
    v_code := public.approve_claim(v_claim_sub, 'department');
    if v_code !~ '^[0-9]{6}$' then v_ok := false; end if;
  exception
    when others then
      v_ok := false;
  end;
  perform set_config('request.jwt.claim.sub', v_admin_campus::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin_campus)::text, true);
  begin
    v_code := public.approve_claim(v_claim_code, 'campus');
    if v_code !~ '^[0-9]{6}$' then v_ok := false; end if;
  exception
    when others then
      v_ok := false;
      v_code := null;
  end;
  v_report := v_report || 'Only appropriate staff can approve claims.=' || case when v_ok then 'PASS' else 'FAIL' end || chr(10);

  v_ok := true;
  begin
    perform public.redeem_collection_code(v_claim_expired, '111111');
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%expired%' then v_ok := false; end if;
  end;
  begin
    perform public.redeem_collection_code(v_claim_used, '222222');
    v_ok := false;
  exception
    when others then
      if sqlerrm not ilike '%already used%' then v_ok := false; end if;
  end;
  if v_code is null then
    v_ok := false;
  else
    begin
      if public.redeem_collection_code(v_claim_code, v_code) is distinct from 'completed' then
        v_ok := false;
      end if;
    exception
      when others then
        v_ok := false;
    end;
    begin
      perform public.redeem_collection_code(v_claim_code, v_code);
      v_ok := false;
    exception
      when others then
        if sqlerrm not ilike '%not ready%' and sqlerrm not ilike '%already used%' then
          v_ok := false;
        end if;
    end;
  end if;
  v_report := v_report || 'Expired or used collection codes cannot be reused.=' || case when v_ok then 'PASS' else 'FAIL' end || chr(10);

  execute 'set local role anon';
  begin
    perform 1 from public.items;
    v_report := v_report || 'Public users cannot bypass RLS.=FAIL' || chr(10);
  exception
    when insufficient_privilege then
      v_report := v_report || 'Public users cannot bypass RLS.=PASS' || chr(10);
    when others then
      v_report := v_report || 'Public users cannot bypass RLS.=FAIL ' || sqlerrm || chr(10);
  end;

  execute 'reset role';
  insert into private.rbac_probe_report (line) values (v_report);
  delete from public.item_handovers
  where staff_id in (select id from public.profiles where email like 'rbac-%@example.test');
  delete from auth.users where email like 'rbac-%@example.test';
  delete from public.universities where slug = 'rbac-other';
  delete from public.departments where name like 'RBAC %';
end
$rbac$;
