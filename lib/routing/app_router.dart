import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../domain/access_role.dart';
import '../features/access/role_dashboard_page.dart';
import '../features/auth/auth_pages.dart';
import '../features/claims/claim_pages.dart';
import '../features/feed/feed_page.dart';
import '../features/items/item_pages.dart';
import '../features/map/map_page.dart';
import '../features/profile/profile_pages.dart';
import '../features/search/search_page.dart';
import '../features/shell/app_shell.dart';
import '../features/staff/staff_pages.dart';

GoRouter buildRouter(CampusStore store) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: store,
    redirect: (context, state) {
      final path = state.uri.path;
      if (!store.ready) return path == '/splash' ? null : '/splash';
      if (path == '/splash') return null;
      final me = store.me;
      final public =
          path == '/onboarding' ||
          path == '/login' ||
          path == '/register' ||
          path == '/privacy' ||
          path == '/recover';
      if (!store.seenOnboarding && path != '/onboarding') return '/onboarding';
      if (store.seenOnboarding && path == '/onboarding') {
        if (me == null) return '/login';
        return signedInHome(
          role: me.role,
          isStaff: me.isStaff,
          serverAccount: store.serverAccount,
        );
      }
      if (me == null) return public ? null : '/login';
      if (!me.emailVerified && path != '/verify') return '/verify';
      if (me.emailVerified &&
          (path == '/verify' || path == '/login' || path == '/register')) {
        return signedInHome(
          role: me.role,
          isStaff: me.isStaff,
          serverAccount: store.serverAccount,
        );
      }
      if (path.startsWith('/staff') && !me.isStaff) return '/feed';
      final dashboard = dashboardRedirect(
        path: path,
        role: me.role,
        isStaff: me.isStaff,
        serverAccount: store.serverAccount,
      );
      if (dashboard != null) return dashboard;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/recover', builder: (_, _) => const RecoverPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyPage()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
          GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
          GoRoute(path: '/map', builder: (_, _) => const MapPage()),
          GoRoute(path: '/claims', builder: (_, _) => const ClaimsPage()),
          GoRoute(
            path: '/claims/:id',
            builder: (_, state) =>
                ClaimDetailPage(id: state.pathParameters['id']!),
          ),
          GoRoute(path: '/activity', builder: (_, _) => const ActivityPage()),
          GoRoute(path: '/saved', builder: (_, _) => const SavedPage()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(
            path: '/profile/edit',
            builder: (_, _) => const EditProfilePage(),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          GoRoute(path: '/items/new', builder: (_, _) => const NewItemPage()),
          GoRoute(
            path: '/items/:id',
            builder: (_, state) =>
                ItemDetailPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/items/:id/claim',
            builder: (_, state) =>
                NewClaimPage(itemId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/superadmin',
            builder: (_, _) =>
                const RoleDashboardPage(role: AccessRole.superadmin),
          ),
          GoRoute(
            path: '/institution-admin',
            builder: (_, _) => const RoleDashboardPage(role: AccessRole.admin),
          ),
          GoRoute(
            path: '/department-admin',
            builder: (_, _) =>
                const RoleDashboardPage(role: AccessRole.subadmin),
          ),
          GoRoute(
            path: '/student',
            builder: (_, _) =>
                const RoleDashboardPage(role: AccessRole.student),
          ),
          GoRoute(path: '/staff', builder: (_, _) => const StaffHomePage()),
          GoRoute(
            path: '/staff/reviews',
            builder: (_, _) => const ReviewListPage(),
          ),
          GoRoute(
            path: '/staff/reviews/:id',
            builder: (_, state) =>
                ReviewDetailPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/staff/compare/:itemId',
            builder: (_, state) =>
                ComparePage(itemId: state.pathParameters['itemId']!),
          ),
          GoRoute(
            path: '/staff/inventory',
            builder: (_, _) => const InventoryPage(),
          ),
          GoRoute(
            path: '/staff/moderation',
            builder: (_, _) => const ModerationPage(),
          ),
          GoRoute(
            path: '/staff/more',
            builder: (_, _) => const StaffMorePage(),
          ),
          GoRoute(
            path: '/staff/members',
            builder: (_, _) => const MembersPage(),
          ),
          GoRoute(path: '/staff/audit', builder: (_, _) => const AuditPage()),
          GoRoute(
            path: '/staff/settings',
            builder: (_, _) => const StaffSettingsPage(),
          ),
        ],
      ),
    ],
  );
}
