import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../backend/backend_config.dart';
import '../../data/logic.dart';
import '../../domain/access_role.dart';
import '../../theme/campus_theme.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final me = store.me;
    final posts = store.items.where((item) => item.authorId == me?.id).toList();
    final returned = posts
        .where((item) => item.type == 'found' && item.status == 'returned')
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          const AccountMenuButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              PersonAvatar(person: me, radius: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me?.name ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(me?.department ?? ''),
                    if (me?.isStaff == true)
                      const StatusPill(label: 'Campus staff', tone: 'info'),
                  ],
                ),
              ),
            ],
          ),
          if ((me?.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(me!.bio),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Posts', value: '${posts.length}'),
              _Stat(label: 'Returned', value: '$returned'),
              _Stat(label: 'Claims', value: '${store.myClaims().length}'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your posts',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (posts.isEmpty) const Text('You have not posted yet.'),
          for (final item in posts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${item.ref} · ${statusLabel(item.status)}'),
              onTap: () => context.push('/items/${item.id}'),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  TextEditingController? _name;
  TextEditingController? _department;
  TextEditingController? _bio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = CampusScope.of(context).me;
    _name ??= TextEditingController(text: me?.name ?? '');
    _department ??= TextEditingController(text: me?.department ?? '');
    _bio ??= TextEditingController(text: me?.bio ?? '');
  }

  @override
  void dispose() {
    _name?.dispose();
    _department?.dispose();
    _bio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _department,
            decoration: const InputDecoration(labelText: 'Department'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              store.updateProfile(
                name: _name?.text ?? '',
                department: _department?.text ?? '',
                bio: _bio?.text ?? '',
              );
              context.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final items = store.savedItems();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved posts')),
      body: items.isEmpty
          ? const EmptyView(
              title: 'No saved posts',
              body: 'Tap the bookmark on a post to keep it here.',
              icon: Icons.bookmark_border,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ItemCard(
                    item: item,
                    place: store.placeName(item.placeId),
                    author: store.person(item.authorId),
                    saved: true,
                    onTap: () => context.push('/items/${item.id}'),
                    onSave: () => CampusRemote.savePost(store, item.id),
                  ),
                );
              },
            ),
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final notices = store.myNotices;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          actions: [
            TextButton(
              onPressed: store.markAllRead,
              child: const Text('Mark read'),
            ),
            const AccountMenuButton(),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notices'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            notices.isEmpty
                ? const EmptyView(
                    title: 'You are up to date',
                    body: 'Claim updates and matches will show up here.',
                    icon: Icons.notifications_none,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notice = notices[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            notice.read
                                ? Icons.notifications_none
                                : Icons.notifications,
                            color: campusBlue,
                          ),
                          title: Text(
                            notice.title,
                            style: TextStyle(
                              fontWeight: notice.read
                                  ? FontWeight.w500
                                  : FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${notice.body}\n${formatWhen(notice.at)}',
                          ),
                          isThreeLine: true,
                          onTap: () {
                            store.markRead(notice.id);
                            context.go(notice.route);
                          },
                        ),
                      );
                    },
                  ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Your claims',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final claim in store.myClaims())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(store.item(claim.itemId)?.title ?? 'Claim'),
                    subtitle: Text(
                      '${statusLabel(claim.status)} · ${formatWhen(claim.createdAt)}',
                    ),
                    onTap: () => context.push('/claims/${claim.id}'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Your posts',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final item in store.items.where(
                  (item) => item.authorId == store.me?.id,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.ref} · ${formatWhen(item.createdAt)}',
                    ),
                    onTap: () => context.push('/items/${item.id}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _deletePassword = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _deletePassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final me = store.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              BackendConfig.fromEnvironment().isConfigured
                  ? 'Shared database configured'
                  : 'Shared database not connected',
            ),
            subtitle: const Text(
              'Posts stay on this phone until config/supabase.dev.json is filled from the Supabase dashboard and the app is run with --dart-define-from-file. The service role key is never stored in the app.',
            ),
          ),
          if (parseAccessRole(me?.role) case final access?)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dashboardTitle(access)),
              subtitle: const Text(
                'Opens the workspace for the role stored on this account. It cannot change that role.',
              ),
              onTap: () => context.push(dashboardPath(access)),
            ),
          const Text(
            'Appearance',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {store.themeMode},
            onSelectionChanged: (value) => store.setTheme(value.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications'),
            value: me?.notifications ?? true,
            onChanged: store.setMyNotifications,
          ),
          const Divider(),
          const Text(
            'Change password',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final error = store.changePassword(_current.text, _next.text);
              toast(context, error ?? 'Password updated on this phone.');
              if (error == null) {
                _current.clear();
                _next.clear();
              }
            },
            child: const Text('Update password'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Password reset emails are not connected. SMTP is not configured.',
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Download my data'),
            subtitle: const Text(
              'A JSON copy of your posts, claims and notices on this phone.',
            ),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: store.exportJson()));
              if (context.mounted)
                toast(context, 'Copied your data to the clipboard.');
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy'),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reset local demo'),
            subtitle: const Text(
              'Restores the sample campus and signs you out.',
            ),
            onTap: () async {
              await store.resetDemo();
            },
          ),
          const Divider(),
          const Text(
            'Delete account',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deletePassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: me?.isAdmin == true
                ? null
                : () {
                    if (store.me?.passwordHash !=
                        hashPassword(_deletePassword.text)) {
                      toast(context, "That password isn't right.");
                      return;
                    }
                    store.deleteMyAccount();
                  },
            child: Text(
              me?.isAdmin == true
                  ? 'Admins cannot delete themselves'
                  : 'Delete account',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: store.signOut, child: const Text('Sign out')),
          const SizedBox(height: 16),
          Text(
            'Lost & Found is a student project. Google sign-in and email are not connected. Nothing here is an official university service.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'What this phone stores',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Until a shared database is connected, posts, photos, claims and your password hash stay on this device. They are not sent to the website.',
          ),
          SizedBox(height: 16),
          Text(
            'Private ownership details',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'A found item can include a detail only the owner would know. That text is hidden from other students. The claimant, the finder, and campus staff can see what they need to review a claim. Evidence photos follow the same rule.',
          ),
          SizedBox(height: 16),
          Text('Decisions', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
            'A match hint can point out similar words. It does not approve ownership. A person approves or rejects the claim and can ask for more information.',
          ),
          SizedBox(height: 16),
          Text('Your choices', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
            'You can copy a JSON export of your own records, change your password, or delete the account from Account settings. Deleting an account removes your lost reports. Found items already held by the office stay with the office.',
          ),
          SizedBox(height: 16),
          Text(
            'This sample is not a Ravensbourne University service and does not use university SSO. A real deployment would need the institution’s own privacy notice, retention rules and lawful basis.',
          ),
        ],
      ),
    );
  }
}
