import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../domain/access_role.dart';

class RoleDashboardPage extends StatelessWidget {
  const RoleDashboardPage({super.key, required this.role});

  final AccessRole role;

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final mine = parseAccessRole(store.me?.role);
    final allowed = mine == role;
    final openItems = store.items.where((item) => item.isOpen).length;
    final pending = store.claims
        .where(
          (claim) => claim.status == 'pending' || claim.status == 'needsInfo',
        )
        .length;
    final unread = store.notices
        .where((notice) => notice.userId == store.me?.id && !notice.read)
        .length;
    return Scaffold(
      appBar: AppBar(title: Text(dashboardTitle(role))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            allowed
                ? 'Signed in as ${store.me?.name ?? 'this account'}.'
                : 'This dashboard is closed.',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            allowed
                ? 'These numbers come from the records this account is allowed to see.'
                : 'The database decides this role. This screen cannot promote an account.',
          ),
          if (allowed) ...[
            const SizedBox(height: 16),
            Text('Open posts: $openItems'),
            Text('Claims waiting: $pending'),
            Text('Unread notices: $unread'),
            if (store.departmentNames.isNotEmpty)
              Text('Departments: ${store.departmentNames.join(', ')}'),
            const SizedBox(height: 12),
            for (final link in _links(role))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.arrow_forward),
                title: Text(link.$1),
                onTap: () => context.go(link.$2),
              ),
          ],
        ],
      ),
    );
  }
}

List<(String, String)> _links(AccessRole role) {
  switch (role) {
    case AccessRole.superadmin:
    case AccessRole.admin:
    case AccessRole.subadmin:
      return const [
        ('Review claims', '/staff'),
        ('Audit history', '/staff/audit'),
        ('Campus feed', '/feed'),
      ];
    case AccessRole.student:
      return const [
        ('Campus feed', '/feed'),
        ('My claims', '/claims'),
        ('Saved posts', '/saved'),
        ('Notices', '/activity'),
      ];
  }
}
