import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../data/logic.dart';
import '../../widgets/common.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.id});
  final String id;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final item = store.item(widget.id);
    if (item == null || item.campusId != store.me?.campusId) {
      return const Scaffold(
        body: EmptyView(
          title: 'Post not available',
          body: 'It may be on another campus, or it has been removed.',
        ),
      );
    }
    final author = store.person(item.authorId);
    final comments = store.commentsFor(item.id);
    final related = store
        .claimsForItem(item.id)
        .where((claim) => store.canReview(item) || claim.userId == store.me?.id)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(item.ref)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ItemArtwork(item: item, height: 240),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              StatusPill(
                label: item.type == 'found' ? 'Found' : 'Lost',
                tone: item.type == 'found' ? 'found' : 'lost',
              ),
              StatusPill(label: statusLabel(item.status)),
              StatusPill(label: item.colour, tone: 'info'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${store.placeName(item.placeId)} · ${formatWhen(item.createdAt)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: const TextStyle(height: 1.45, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(person: author),
            title: Text(
              author?.name ?? 'Campus member',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(author?.department ?? ''),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => CampusRemote.savePost(store, item.id),
                  icon: Icon(
                    store.isSaved(item.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                  label: Text(store.isSaved(item.id) ? 'Saved' : 'Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => store.toggleLike(item.id),
                  icon: Icon(
                    store.likedByMe(item.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  label: Text('${item.likeCount}'),
                ),
              ),
            ],
          ),
          if (store.canSeePrivate(item) && item.privateDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Shown to you because you posted this, or because you are campus staff. Other students do not see this.',
                    ),
                    const SizedBox(height: 8),
                    Text(item.privateDetails),
                  ],
                ),
              ),
            ),
          ],
          if (item.type == 'found' &&
              item.status == 'open' &&
              item.authorId != store.me?.id) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/items/${item.id}/claim'),
              child: const Text('This is mine'),
            ),
          ],
          if (related.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Claims',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            for (final claim in related)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(store.person(claim.userId)?.name ?? 'Claimant'),
                subtitle: Text(statusLabel(claim.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  store.me?.isStaff == true
                      ? '/staff/reviews/${claim.id}'
                      : '/claims/${claim.id}',
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final reason = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Report this post'),
                  children: [
                    for (final reason in const [
                      'Scam or false claim',
                      'Shares personal information',
                      'Harassment',
                      'Spam',
                      'Something else',
                    ])
                      SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, reason),
                        child: Text(reason),
                      ),
                  ],
                ),
              );
              if (reason == null || !context.mounted) return;
              final error = store.reportContent(
                itemId: item.id,
                reason: reason,
              );
              if (!context.mounted) return;
              toast(context, error ?? 'Report sent to campus staff.');
            },
            child: const Text('Report post'),
          ),
          const SizedBox(height: 8),
          Text(
            'Comments',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty) const Text('No comments yet.'),
          for (final comment in comments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(
                person: store.person(comment.authorId),
                radius: 16,
              ),
              title: Text(store.person(comment.authorId)?.name ?? ''),
              subtitle: Text(comment.text),
              trailing: IconButton(
                tooltip: 'Report comment',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () {
                  final error = store.reportContent(
                    itemId: item.id,
                    commentId: comment.id,
                    reason: 'Reported comment',
                  );
                  toast(context, error ?? 'Report sent.');
                },
              ),
            ),
          TextField(
            controller: _comment,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Add a comment'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final before = store.commentsFor(item.id).length;
              final message = store.addComment(item.id, _comment.text);
              final added = store.commentsFor(item.id).length > before;
              if (added) _comment.clear();
              if (message != null) toast(context, message);
              if (!added && message == null)
                toast(context, 'Write a comment first.');
            },
            child: const Text('Comment'),
          ),
        ],
      ),
    );
  }
}

class NewItemPage extends StatefulWidget {
  const NewItemPage({super.key});

  @override
  State<NewItemPage> createState() => _NewItemPageState();
}

class _NewItemPageState extends State<NewItemPage> {
  String _type = 'lost';
  String _category = categories.first;
  String _colour = 'Blue';
  String? _placeId;
  String? _photo;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _private = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _private.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final places = store.myPlaces;
    _placeId ??= places.isEmpty ? null : places.first.id;
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'lost', label: Text('I lost something')),
              ButtonSegment(value: 'found', label: Text('I found something')),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _colour,
            decoration: const InputDecoration(labelText: 'Colour'),
            items: [
              for (final colour in colours)
                DropdownMenuItem(value: colour, child: Text(colour)),
            ],
            onChanged: (value) => setState(() => _colour = value ?? _colour),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _placeId,
            decoration: const InputDecoration(labelText: 'Location'),
            items: [
              for (final place in places)
                DropdownMenuItem(value: place.id, child: Text(place.name)),
            ],
            onChanged: (value) => setState(() => _placeId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          if (_type == 'found') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _private,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What would only the owner know?',
                helperText: 'This stays off the public post.',
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await pickCampusPhoto(context);
              if (path != null) setState(() => _photo = path);
            },
            icon: const Icon(Icons.photo_outlined),
            label: Text(_photo == null ? 'Add a photo' : 'Photo added'),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_photo!),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _placeId == null
                ? null
                : () async {
                    setState(() => _busy = true);
                    final error = store.serverAccount
                        ? await CampusRemote.publishItem(
                            store,
                            type: _type,
                            title: _title.text,
                            category: _category,
                            colour: _colour,
                            placeId: _placeId!,
                            description: _description.text,
                            privateDetails: _private.text,
                            photoPath: _photo,
                          )
                        : store.createItem(
                            type: _type,
                            title: _title.text,
                            category: _category,
                            colour: _colour,
                            placeId: _placeId!,
                            description: _description.text,
                            privateDetails: _private.text,
                            photoPath: _photo,
                          );
                    if (!mounted || !context.mounted) return;
                    if (error != null) {
                      setState(() {
                        _busy = false;
                        _error = error;
                      });
                      return;
                    }
                    context.pop();
                  },
            child: Text(_busy ? 'Posting…' : 'Publish post'),
          ),
        ],
      ),
    );
  }
}
