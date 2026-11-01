import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_mobile/domain/access_role.dart';

void main() {
  test('students cannot grant themselves a higher role', () {
    expect(parseAccessRole('student'), AccessRole.student);
    expect(parseAccessRole('member'), isNull);
    expect(parseAccessRole('staff'), isNull);
    expect(parseAccessRole('ADMIN'), isNull);
    expect(parseAccessRole('superadmin '), isNull);

    expect(
      canGrant(
        actor: AccessRole.student,
        target: AccessRole.admin,
        sameInstitution: true,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: AccessRole.student,
        target: AccessRole.superadmin,
        sameInstitution: true,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: null,
        target: AccessRole.admin,
        sameInstitution: true,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: AccessRole.subadmin,
        target: AccessRole.student,
        sameInstitution: true,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: AccessRole.admin,
        target: AccessRole.admin,
        sameInstitution: true,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: AccessRole.admin,
        target: AccessRole.subadmin,
        sameInstitution: false,
      ),
      isFalse,
    );
    expect(
      canGrant(
        actor: AccessRole.admin,
        target: AccessRole.student,
        sameInstitution: true,
      ),
      isTrue,
    );
    expect(
      canGrant(
        actor: AccessRole.superadmin,
        target: AccessRole.admin,
        sameInstitution: false,
      ),
      isTrue,
    );
  });

  test('dashboard routes stay on the signed-in role', () {
    expect(
      dashboardRedirect(path: '/superadmin', role: 'student', isStaff: false),
      '/feed',
    );
    expect(
      dashboardRedirect(path: '/institution-admin', role: 'student', isStaff: false),
      '/feed',
    );
    expect(
      dashboardRedirect(path: '/department-admin', role: 'admin', isStaff: true),
      '/staff',
    );
    expect(
      dashboardRedirect(path: '/student', role: 'member', isStaff: false),
      '/feed',
    );
    expect(
      dashboardRedirect(path: '/superadmin', role: 'superadmin', isStaff: false),
      isNull,
    );
    expect(
      dashboardRedirect(path: '/feed', role: 'student', isStaff: false),
      isNull,
    );
    expect(
      dashboardRedirect(path: '/staff', role: 'staff', isStaff: true),
      isNull,
    );
  });

  test('no service-role key is present in client bundles', () {
    final roots = <Directory>[
      Directory('lib'),
      Directory('android'),
      Directory('ios/Runner'),
      Directory('web'),
    ];
    final forbidden = [
      'service_role',
      'sb_secret_',
      'SUPABASE_SERVICE_ROLE',
    ];
    final hits = <String>[];
    for (final root in roots) {
      if (!root.existsSync()) {
        hits.add('MISSING ${root.path}');
        continue;
      }
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('/build/') || path.contains('/.dart_tool/')) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jar')) {
          continue;
        }
        final text = _readText(entity);
        if (text == null) continue;
        for (final token in forbidden) {
          if (text.contains(token)) hits.add('$path contains $token');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}

String? _readText(File file) {
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}
