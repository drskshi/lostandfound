/// Server role names. The phone demo roles member and staff are not these.
enum AccessRole { superadmin, admin, subadmin, student }

AccessRole? parseAccessRole(String? value) {
  switch (value) {
    case 'superadmin':
      return AccessRole.superadmin;
    case 'admin':
      return AccessRole.admin;
    case 'subadmin':
      return AccessRole.subadmin;
    case 'student':
      return AccessRole.student;
    default:
      return null;
  }
}

/// Mirrors private.grant_role. A student, sub-admin, or unknown role cannot grant.
bool canGrant({
  required AccessRole? actor,
  required AccessRole target,
  required bool sameInstitution,
}) {
  if (actor == AccessRole.superadmin) return true;
  if (actor == AccessRole.admin &&
      sameInstitution &&
      (target == AccessRole.student || target == AccessRole.subadmin)) {
    return true;
  }
  return false;
}

/// Where a signed-in account lands. A Supabase session uses the server role.
/// The on-phone demo keeps its existing staff and feed destinations.
String signedInHome({
  required String? role,
  required bool isStaff,
  required bool serverAccount,
}) {
  if (serverAccount) {
    final access = parseAccessRole(role);
    if (access != null) return dashboardPath(access);
  }
  return isStaff ? '/staff' : '/feed';
}

String dashboardPath(AccessRole role) {
  switch (role) {
    case AccessRole.superadmin:
      return '/superadmin';
    case AccessRole.admin:
      return '/institution-admin';
    case AccessRole.subadmin:
      return '/department-admin';
    case AccessRole.student:
      return '/student';
  }
}

String dashboardTitle(AccessRole role) {
  switch (role) {
    case AccessRole.superadmin:
      return 'Platform dashboard';
    case AccessRole.admin:
      return 'Institution dashboard';
    case AccessRole.subadmin:
      return 'Department dashboard';
    case AccessRole.student:
      return 'Student dashboard';
  }
}

/// Returns the existing home when [path] is a role dashboard the account cannot open.
String? dashboardRedirect({
  required String path,
  required String? role,
  required bool isStaff,
  bool serverAccount = false,
}) {
  final access = parseAccessRole(role);
  final home = signedInHome(
    role: role,
    isStaff: isStaff,
    serverAccount: serverAccount,
  );
  if (path.startsWith('/superadmin') && access != AccessRole.superadmin) {
    return home;
  }
  if (path.startsWith('/institution-admin') && access != AccessRole.admin) {
    return home;
  }
  if (path.startsWith('/department-admin') && access != AccessRole.subadmin) {
    return home;
  }
  if (path.startsWith('/student') && access != AccessRole.student) {
    return home;
  }
  return null;
}
