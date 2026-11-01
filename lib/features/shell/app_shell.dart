import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../widgets/common.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final store = CampusScope.of(context);
    final staff = path.startsWith('/staff');
    final index = _index(path, staff);
    final destinations = staff
        ? const [
            (Icons.dashboard_outlined, 'Overview'),
            (Icons.fact_check_outlined, 'Reviews'),
            (Icons.inventory_2_outlined, 'Inventory'),
            (Icons.shield_outlined, 'Reports'),
            (Icons.more_horiz, 'More'),
          ]
        : const [
            (Icons.home_outlined, 'Feed'),
            (Icons.search, 'Search'),
            (Icons.map_outlined, 'Map'),
            (Icons.assignment_outlined, 'Claims'),
            (Icons.notifications_outlined, 'Activity'),
          ];
    final showPost = path == '/feed' || path == '/search' || path == '/map';
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1100;
    final tablet = width >= 700;
    void go(int value) {
      if (staff) {
        const routes = [
          '/staff',
          '/staff/reviews',
          '/staff/inventory',
          '/staff/moderation',
          '/staff/more',
        ];
        context.go(routes[value]);
      } else {
        const routes = ['/feed', '/search', '/map', '/claims', '/activity'];
        context.go(routes[value]);
      }
    }

    final rail = NavigationRail(
      selectedIndex: index,
      onDestinationSelected: go,
      labelType: desktop
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      extended: desktop,
      destinations: [
        for (final item in destinations)
          NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$2)),
      ],
    );
    return Scaffold(
      body: tablet
          ? Row(
              children: [
                rail,
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : child,
      floatingActionButton: showPost
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/items/new'),
              icon: const Icon(Icons.add),
              label: const Text('Post'),
            )
          : null,
      bottomNavigationBar: tablet
          ? null
          : NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final item in destinations)
            NavigationDestination(
              icon: item.$1 == Icons.notifications_outlined && store.unread > 0
                  ? Badge(label: Text('${store.unread}'), child: Icon(item.$1))
                  : Icon(item.$1),
              label: item.$2,
            ),
        ],
        onDestinationSelected: go,
      ),
    );
  }

  int _index(String path, bool staff) {
    if (staff) {
      if (path.startsWith('/staff/reviews') ||
          path.startsWith('/staff/compare'))
        return 1;
      if (path.startsWith('/staff/inventory')) return 2;
      if (path.startsWith('/staff/moderation')) return 3;
      if (path.startsWith('/staff/more') ||
          path.startsWith('/staff/members') ||
          path.startsWith('/staff/audit') ||
          path.startsWith('/staff/settings'))
        return 4;
      return 0;
    }
    if (path.startsWith('/search')) return 1;
    if (path.startsWith('/map')) return 2;
    if (path.startsWith('/claims')) return 3;
    if (path.startsWith('/activity')) return 4;
    return 0;
  }
}

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    return IconButton(
      tooltip: 'Account',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: PersonAvatar(person: store.me),
                  title: Text(store.me?.name ?? ''),
                  subtitle: Text(store.campus?.name ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Saved posts'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/saved');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Account settings'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                if (store.me?.isStaff == true)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Staff workspace'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/staff');
                    },
                  ),
                if (store.me?.isStaff == true &&
                    !GoRouterState.of(context).uri.path.startsWith('/staff'))
                  const SizedBox.shrink(),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Student feed'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/feed');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () {
                    Navigator.pop(context);
                    store.signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
      icon: PersonAvatar(person: store.me, radius: 16),
    );
  }
}
