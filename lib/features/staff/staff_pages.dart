import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../data/store.dart';
import '../../data/models.dart';
import '../../theme/campus_theme.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

class StaffHomePage extends StatelessWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final campusId = store.me?.campusId;
    final open = store.items
        .where((item) => item.campusId == campusId && item.status == 'open')
        .length;
    final pending = store
        .reviewQueue()
        .where(
          (claim) => claim.status == 'pending' || claim.status == 'needsInfo',
        )
        .length;
    final reports = store.openReports().length;
    final returned = store.items
        .where((item) => item.campusId == campusId && item.status == 'returned')
        .length;
    final counts = <String, int>{};
    for (final item in store.items.where(
      (item) => item.campusId == campusId && item.type == 'found',
    )) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: const [AccountMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            store.campus?.name ?? 'Campus',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Signed in as ${store.me?.name}. This workspace uses the role saved on the account.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(label: 'Open items', value: '$open'),
              _Metric(label: 'Claims to review', value: '$pending'),
              _Metric(label: 'Open reports', value: '$reports'),
              _Metric(label: 'Returned', value: '$returned'),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Found items by category',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final entry in counts.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: entry.value / maxCount,
                        minHeight: 10,
                        color: campusBlue,
                        backgroundColor: campusSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${entry.value}'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/staff/reviews'),
            child: const Text('Open claim reviews'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewListPage extends StatelessWidget {
  const ReviewListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final claims = store.reviewQueue();
    final grouped = <String, List<Claim>>{};
    for (final claim in claims) {
      grouped.putIfAbsent(claim.itemId, () => []).add(claim);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim reviews'),
        actions: const [AccountMenuButton()],
      ),
      body: claims.isEmpty
          ? const EmptyView(
              title: 'Queue is clear',
              body: 'New ownership claims will appear here.',
              icon: Icons.fact_check_outlined,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries) ...[
                  if (entry.value.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.push('/staff/compare/${entry.key}'),
                        child: Text('Compare ${entry.value.length} claims'),
                      ),
                    ),
                  for (final claim in entry.value) _ReviewTile(claim: claim),
                ],
              ],
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.claim});
  final Claim claim;

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final item = store.item(claim.itemId);
    final risk = store.riskFor(claim);
    final assist = store.assistFor(claim);
    return Card(
      child: ListTile(
        title: Text(item?.title ?? 'Item'),
        subtitle: Text(
          '${store.person(claim.userId)?.name ?? ''} · ${statusLabel(claim.status)}\nHint ${assist.score}% · ${risk.level} risk',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/staff/reviews/${claim.id}'),
      ),
    );
  }
}

class ReviewDetailPage extends StatefulWidget {
  const ReviewDetailPage({super.key, required this.id});
  final String id;

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final _note = TextEditingController();
  final _code = TextEditingController();
  bool _checked = false;

  @override
  void dispose() {
    _note.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final claim = store.claim(widget.id);
    final item = claim == null ? null : store.item(claim.itemId);
    if (claim == null || item == null || !store.canReview(item)) {
      return const Scaffold(
        body: EmptyView(
          title: 'Not available',
          body: 'You do not have permission to review this claim.',
        ),
      );
    }
    final assist = store.assistFor(claim);
    final risk = store.riskFor(claim);
    final others = store
        .claimsForItem(item.id)
        .where((other) => other.id != claim.id)
        .length;
    return Scaffold(
      appBar: AppBar(title: Text(item.ref)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            '${store.person(claim.userId)?.name ?? ''} · ${statusLabel(claim.status)}',
          ),
          if (others > 0)
            TextButton(
              onPressed: () => context.push('/staff/compare/${item.id}'),
              child: Text(
                '$others other claim${others == 1 ? '' : 's'} on this item',
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Private details',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            item.privateDetails.isEmpty ? 'None recorded' : item.privateDetails,
          ),
          const SizedBox(height: 12),
          const Text(
            'Claimant’s description',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(claim.description),
          const SizedBox(height: 8),
          Text('${claim.where} · ${claim.when}'),
          const SizedBox(height: 12),
          Text(
            'Word hint: ${assist.score}%. ${assist.matched.isEmpty ? 'No private words matched.' : 'Matched: ${assist.matched.join(', ')}'}',
          ),
          Text(
            'This hint does not approve ownership.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          StatusPill(
            label: '${risk.level} risk',
            tone: risk.level == 'high'
                ? 'bad'
                : risk.level == 'medium'
                ? 'lost'
                : 'good',
          ),
          for (final signal in risk.signals) Text('· $signal'),
          if (store.canSeeEvidence(claim) &&
              claim.evidencePath != null &&
              File(claim.evidencePath!).existsSync()) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(claim.evidencePath!),
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (claim.status == 'pending' || claim.status == 'needsInfo') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Decision note'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checked,
              onChanged: (value) => setState(() => _checked = value ?? false),
              title: const Text(
                'I compared the private details with this claim.',
              ),
            ),
            FilledButton(
              onPressed: () => _decide(store, claim.id, 'approve'),
              child: const Text('Approve claim'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _decide(store, claim.id, 'needsInfo'),
              child: const Text('Request information'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _decide(store, claim.id, 'reject'),
              child: const Text('Reject claim'),
            ),
          ],
          if (claim.status == 'approved') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Collection code'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (!store.serverAccount) {
                  final error = store.handover(claim.id, _code.text);
                  toast(context, error ?? 'Handover confirmed.');
                  return;
                }
                CampusRemote.redeem(store, claim.id, _code.text).then((error) {
                  if (!context.mounted) return;
                  toast(context, error ?? 'Handover confirmed.');
                });
              },
              child: const Text('Verify code and complete handover'),
            ),
            TextButton(
              onPressed: () => store.reissue(claim.id),
              child: const Text('Reissue code'),
            ),
          ],
        ],
      ),
    );
  }

  void _decide(CampusStore store, String id, String decision) {
    if (decision == 'approve' && !_checked) {
      toast(context, 'Confirm that you compared the evidence.');
      return;
    }
    if (!store.serverAccount) {
      final error = store.decide(
        claimId: id,
        decision: decision,
        note: _note.text,
      );
      toast(context, error ?? 'Decision saved.');
      return;
    }
    CampusRemote.decide(
      store,
      claimId: id,
      decision: decision,
      note: _note.text,
    ).then((error) {
      if (!mounted) return;
      toast(context, error ?? 'Decision saved.');
    });
  }
}

class ComparePage extends StatelessWidget {
  const ComparePage({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final item = store.item(itemId);
    if (item == null || !store.canReview(item)) {
      return const Scaffold(
        body: EmptyView(
          title: 'Not available',
          body: 'You cannot compare these claims.',
        ),
      );
    }
    final claims = store.claimsForItem(itemId);
    return Scaffold(
      appBar: AppBar(title: const Text('Compare claims')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Private details',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            item.privateDetails.isEmpty ? 'None recorded' : item.privateDetails,
          ),
          const SizedBox(height: 12),
          for (final claim in claims) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.person(claim.userId)?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(statusLabel(claim.status)),
                    const SizedBox(height: 8),
                    Text(claim.description),
                    const SizedBox(height: 8),
                    Text(
                      'Hint ${store.assistFor(claim).score}% · ${store.riskFor(claim).level} risk',
                    ),
                    for (final signal in store.riskFor(claim).signals)
                      Text('· $signal'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.push('/staff/reviews/${claim.id}'),
                        child: const Text('Open'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final rows = store.items
        .where(
          (item) =>
              item.campusId == store.me?.campusId &&
              item.type == 'found' &&
              item.status != 'returned',
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item inventory'),
        actions: const [AccountMenuButton()],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final item = rows[index];
          final days = item.retainUntil.difference(DateTime.now()).inDays;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${item.ref} · Shelf ${item.shelf} · ${store.placeName(item.placeId)}',
                  ),
                  Text(
                    days < 0
                        ? 'Holding period ended ${-days} days ago'
                        : '$days days left in the holding period',
                    style: TextStyle(
                      color: days < 0 ? const Color(0xFFB42318) : null,
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => store.extendHold(item.id),
                        child: const Text('Hold 14 more days'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final method = await showDialog<String>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Close item'),
                              children: [
                                for (final method in const [
                                  'Donated to charity',
                                  'Recycled',
                                  'Securely destroyed',
                                  'Returned to issuer',
                                ])
                                  SimpleDialogOption(
                                    onPressed: () =>
                                        Navigator.pop(context, method),
                                    child: Text(method),
                                  ),
                              ],
                            ),
                          );
                          if (method != null) store.closeItem(item.id, method);
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ModerationPage extends StatelessWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final reports = store.openReports();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        actions: const [AccountMenuButton()],
      ),
      body: reports.isEmpty
          ? const EmptyView(
              title: 'No open reports',
              body: 'Flagged comments and posts will queue here.',
              icon: Icons.shield_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final item = store.item(report.itemId);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item?.title ?? 'Post',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(report.reason),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  store.moderate(report.id, 'removed'),
                              child: const Text('Remove'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  store.moderate(report.id, 'dismissed'),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class StaffMorePage extends StatelessWidget {
  const StaffMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: const [AccountMenuButton()],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Campus members'),
            onTap: () => context.push('/staff/members'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Audit trail'),
            onTap: () => context.push('/staff/audit'),
          ),
          if (store.me?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Campus settings'),
              onTap: () => context.push('/staff/settings'),
            ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Student feed'),
            onTap: () => context.go('/feed'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: store.signOut,
          ),
        ],
      ),
    );
  }
}

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final people = store.people
        .where(
          (person) =>
              person.campusId == store.me?.campusId && person.id != 'office',
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Campus members')),
      body: ListView.builder(
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          final locked = person.id == store.me?.id || person.role == 'admin';
          return ListTile(
            leading: PersonAvatar(person: person, radius: 18),
            title: Text(person.name),
            subtitle: Text('${person.email}\n${person.department}'),
            isThreeLine: true,
            trailing: locked
                ? Text(person.role)
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      final error = value == 'suspend' || value == 'restore'
                          ? store.setSuspended(person.id, value == 'suspend')
                          : store.setRole(person.id, value);
                      if (error != null) toast(context, error);
                    },
                    itemBuilder: (context) => [
                      if (store.me?.isAdmin == true)
                        const PopupMenuItem(
                          value: 'member',
                          child: Text('Make member'),
                        ),
                      if (store.me?.isAdmin == true)
                        const PopupMenuItem(
                          value: 'staff',
                          child: Text('Make staff'),
                        ),
                      PopupMenuItem(
                        value: person.status == 'active'
                            ? 'suspend'
                            : 'restore',
                        child: Text(
                          person.status == 'active' ? 'Suspend' : 'Restore',
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final rows = store.audit
        .where((entry) => entry.campusId == store.me?.campusId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Audit trail')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final entry = rows[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              entry.action,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${entry.detail}\n${entry.actor} · ${formatDate(entry.at)}',
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}

class StaffSettingsPage extends StatelessWidget {
  const StaffSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    if (store.me?.isAdmin != true) {
      return const Scaffold(
        body: EmptyView(
          title: 'Admins only',
          body: 'Campus settings are limited to admin accounts.',
        ),
      );
    }
    final settings = store.campusSettings;
    return Scaffold(
      appBar: AppBar(title: const Text('Campus settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Holding period: ${settings.retentionDays} days'),
          Slider(
            min: 7,
            max: 90,
            divisions: 83,
            value: settings.retentionDays.toDouble(),
            label: '${settings.retentionDays}',
            onChanged: (value) =>
                store.updateStaffSettings(retentionDays: value.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send in-app notices'),
            value: settings.notifications,
            onChanged: (value) =>
                store.updateStaffSettings(notifications: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require a private detail on found posts'),
            value: settings.requireProof,
            onChanged: (value) =>
                store.updateStaffSettings(requireProof: value),
          ),
        ],
      ),
    );
  }
}
