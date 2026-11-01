import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../data/logic.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _type = 'all';
  String _category = 'all';
  int _shown = listPageSize;

  void _pickType(String value) {
    setState(() {
      _type = value;
      _shown = listPageSize;
    });
  }

  void _pickCategory(String value) {
    setState(() {
      _category = value;
      _shown = listPageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final items = store.feedItems(type: _type, category: _category);
    final shown = pageWindow(items, _shown);
    final more = shown.length < items.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus feed'),
        actions: const [AccountMenuButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          itemCount: shown.length + 1 + (more ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${store.me?.name.split(' ').first ?? ''}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.campus?.name ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Posts on this phone stay here until a shared campus database is connected.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final type in const [
                          ('all', 'All'),
                          ('found', 'Found'),
                          ('lost', 'Lost'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(type.$2),
                              selected: _type == type.$1,
                              onSelected: (_) => _pickType(type.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All categories'),
                            selected: _category == 'all',
                            onSelected: (_) => _pickCategory('all'),
                          ),
                        ),
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) => _pickCategory(category),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const EmptyView(
                      title: 'Nothing on the feed',
                      body: 'Try another filter, or post something you lost or found.',
                      icon: Icons.dynamic_feed_outlined,
                    ),
                ],
              );
            }
            if (index == shown.length + 1) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: () => setState(() => _shown += listPageSize),
                  child: Text(
                    'Show more (${items.length - shown.length} left)',
                  ),
                ),
              );
            }
            final item = shown[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ItemCard(
                item: item,
                place: store.placeName(item.placeId),
                author: store.person(item.authorId),
                saved: store.isSaved(item.id),
                onTap: () => context.push('/items/${item.id}'),
                onSave: () => CampusRemote.savePost(store, item.id),
              ),
            );
          },
        ),
      ),
    );
  }
}
