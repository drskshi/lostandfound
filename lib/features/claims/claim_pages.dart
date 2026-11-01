import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

class ClaimsPage extends StatelessWidget {
  const ClaimsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final mine = store.myClaims();
    final review = store
        .reviewQueue()
        .where((claim) => claim.userId != store.me?.id)
        .toList();
    return DefaultTabController(
      length: review.isEmpty ? 1 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My claims'),
          actions: const [AccountMenuButton()],
          bottom: review.isEmpty
              ? null
              : const TabBar(
                  tabs: [
                    Tab(text: 'Mine'),
                    Tab(text: 'To review'),
                  ],
                ),
        ),
        body: review.isEmpty
            ? _ClaimList(
                claims: mine,
                empty: 'You have not submitted a claim yet.',
              )
            : TabBarView(
                children: [
                  _ClaimList(
                    claims: mine,
                    empty: 'You have not submitted a claim yet.',
                  ),
                  _ClaimList(
                    claims: review,
                    empty: 'No claims are waiting on you.',
                  ),
                ],
              ),
      ),
    );
  }
}

class _ClaimList extends StatelessWidget {
  const _ClaimList({required this.claims, required this.empty});
  final List<Claim> claims;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    if (claims.isEmpty)
      return EmptyView(
        title: 'No claims',
        body: empty,
        icon: Icons.assignment_outlined,
      );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: claims.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final claim = claims[index];
        final item = store.item(claim.itemId);
        return Card(
          child: ListTile(
            title: Text(
              item?.title ?? 'Item',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${item?.ref ?? ''} · ${statusLabel(claim.status)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/claims/${claim.id}'),
          ),
        );
      },
    );
  }
}

class ClaimDetailPage extends StatefulWidget {
  const ClaimDetailPage({super.key, required this.id});
  final String id;

  @override
  State<ClaimDetailPage> createState() => _ClaimDetailPageState();
}

class _ClaimDetailPageState extends State<ClaimDetailPage> {
  final _reply = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final claim = store.claim(widget.id);
    final item = claim == null ? null : store.item(claim.itemId);
    if (claim == null || item == null || item.campusId != store.me?.campusId) {
      return const Scaffold(
        body: EmptyView(
          title: 'Claim not available',
          body: 'It is not on your campus.',
        ),
      );
    }
    final mine = claim.userId == store.me?.id;
    final reviewer = store.canReview(item);
    if (!mine && !reviewer) {
      return const Scaffold(
        body: EmptyView(
          title: 'Private claim',
          body: 'Only the claimant and the reviewer can open this.',
        ),
      );
    }
    final place = store.place(item.placeId);
    final collection = place?.collection == true
        ? place!.name
        : 'Security Lodge';
    return Scaffold(
      appBar: AppBar(title: Text(item.ref)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          StatusPill(
            label: statusLabel(claim.status),
            tone: claim.status == 'approved' || claim.status == 'completed'
                ? 'good'
                : claim.status == 'rejected'
                ? 'bad'
                : 'info',
          ),
          const SizedBox(height: 16),
          Text(claim.description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          Text(
            '${claim.where} · ${claim.when}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
          if (store.canSeeEvidence(claim) &&
              claim.evidencePath != null &&
              claim.evidencePath!.startsWith('https://')) ...[
            const SizedBox(height: 12),
            const Text(
              'Private evidence',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                claim.evidencePath!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (store.canSeeEvidence(claim) &&
              claim.evidencePath != null &&
              !claim.evidencePath!.startsWith('https://') &&
              File(claim.evidencePath!).existsSync()) ...[
            const SizedBox(height: 12),
            const Text(
              'Private evidence',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(claim.evidencePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (mine && claim.status == 'approved' && claim.code != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF152D58),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'Collection code',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    claim.code!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Valid until ${formatDate(claim.codeExpires!)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take this to $collection. It works once. Do not post the code in a comment.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
          if (reviewer && claim.status == 'approved') ...[
            const SizedBox(height: 16),
            const Text(
              'Confirm handover',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter the collection code',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (!store.serverAccount) {
                  final error = store.handover(claim.id, _code.text);
                  toast(
                    context,
                    error ??
                        'Handover confirmed. The item is marked as returned.',
                  );
                  return;
                }
                CampusRemote.redeem(store, claim.id, _code.text).then((error) {
                  if (!context.mounted) return;
                  toast(
                    context,
                    error ??
                        'Handover confirmed. The item is marked as returned.',
                  );
                });
              },
              child: const Text('Confirm handover'),
            ),
            if (store.me?.isStaff == true)
              TextButton(
                onPressed: () => store.reissue(claim.id),
                child: const Text('Reissue code'),
              ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < claim.events.length; i++)
            TimelineTile(
              title: claim.events[i].title,
              detail: claim.events[i].detail,
              time: formatWhen(claim.events[i].at),
              last: i == claim.events.length - 1 && claim.messages.isEmpty,
            ),
          if (claim.note.isNotEmpty && claim.status != 'pending')
            Text('Note: ${claim.note}'),
          const SizedBox(height: 12),
          const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final message in claim.messages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(store.person(message.authorId)?.name ?? ''),
              subtitle: Text(message.text),
            ),
          if (claim.status != 'rejected' &&
              claim.status != 'withdrawn' &&
              claim.status != 'completed') ...[
            TextField(
              controller: _reply,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reply'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                final message = store.reply(claim.id, _reply.text);
                if (message == null || message.startsWith('Sent'))
                  _reply.clear();
                if (message != null) toast(context, message);
              },
              child: const Text('Send'),
            ),
          ],
          if (mine && claim.isActive)
            TextButton(
              onPressed: () {
                store.withdrawClaim(claim.id);
                toast(context, 'Claim withdrawn.');
              },
              child: const Text('Withdraw claim'),
            ),
        ],
      ),
    );
  }
}

class NewClaimPage extends StatefulWidget {
  const NewClaimPage({super.key, required this.itemId});
  final String itemId;

  @override
  State<NewClaimPage> createState() => _NewClaimPageState();
}

class _NewClaimPageState extends State<NewClaimPage> {
  final _details = TextEditingController();
  final _where = TextEditingController();
  final _when = TextEditingController();
  bool _declaration = false;
  String? _evidence;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    _where.dispose();
    _when.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final item = store.item(widget.itemId);
    if (item == null)
      return const Scaffold(
        body: EmptyView(title: 'Item missing', body: 'Go back to the feed.'),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Ownership claim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'This description is private. It is shown to the reviewer next to the details only an owner should know. A match score is a hint. A person decides.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Describe the item',
              helperText: 'At least a couple of sentences.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _where,
            decoration: const InputDecoration(
              labelText: 'Where did you lose it?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _when,
            decoration: const InputDecoration(labelText: 'When?'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await pickCampusPhoto(context);
              if (path != null) setState(() => _evidence = path);
            },
            icon: const Icon(Icons.attach_file),
            label: Text(
              _evidence == null ? 'Add private evidence' : 'Evidence added',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _declaration,
            onChanged: (value) => setState(() => _declaration = value ?? false),
            title: const Text(
              'I confirm this is my item and the details are true.',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (!_declaration) {
                      setState(
                        () => _error = 'Please confirm the declaration.',
                      );
                      return;
                    }
                    setState(() => _busy = true);
                    if (store.serverAccount) {
                      final result = await CampusRemote.submitClaim(
                        store,
                        itemId: item.id,
                        description: _details.text,
                        where: _where.text,
                        when: _when.text,
                        evidencePath: _evidence,
                      );
                      if (!mounted || !context.mounted) return;
                      if (result.error != null || result.id == null) {
                        setState(() {
                          _busy = false;
                          _error = result.error ?? 'The claim was not saved.';
                        });
                        return;
                      }
                      context.go('/claims/${result.id}');
                      return;
                    }
                    final error = store.submitClaim(
                      itemId: item.id,
                      description: _details.text,
                      where: _where.text,
                      when: _when.text,
                      evidencePath: _evidence,
                    );
                    if (!mounted) return;
                    if (error != null) {
                      setState(() {
                        _busy = false;
                        _error = error;
                      });
                      return;
                    }
                    final created = store.myClaims().first;
                    context.go('/claims/${created.id}');
                  },
            child: Text(_busy ? 'Sending…' : 'Submit claim'),
          ),
        ],
      ),
    );
  }
}
