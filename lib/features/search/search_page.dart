import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../backend/campus_remote.dart';
import '../../data/logic.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  String _type = 'all';
  String _category = 'all';
  String _colour = 'all';
  String _place = 'all';
  bool _returned = false;
  int _shown = listPageSize;

  void _reset(VoidCallback change) {
    setState(() {
      change();
      _shown = listPageSize;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final results = store.visibleItems(
      type: _type,
      category: _category,
      colour: _colour,
      placeId: _place,
      query: _query.text,
      includeClosed: _returned,
    );
    final shown = pageWindow(results, _shown);
    final more = shown.length < results.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart search'),
        actions: const [AccountMenuButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: (_) => _reset(() {}),
              decoration: const InputDecoration(
                labelText: 'Item name or description',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _menu('Type', _type, const {
                  'all': 'Lost and found',
                  'found': 'Found',
                  'lost': 'Lost',
                }, (value) => _reset(() => _type = value)),
                _menu('Category', _category, {
                  'all': 'All categories',
                  for (final category in categories) category: category,
                }, (value) => _reset(() => _category = value)),
                _menu('Colour', _colour, {
                  'all': 'Any colour',
                  for (final colour in colours) colour: colour,
                }, (value) => _reset(() => _colour = value)),
                _menu('Place', _place, {
                  'all': 'Anywhere',
                  for (final place in store.myPlaces) place.id: place.shortName,
                }, (value) => _reset(() => _place = value)),
                FilterChip(
                  label: const Text('Include returned'),
                  selected: _returned,
                  onSelected: (value) => _reset(() => _returned = value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const EmptyView(
                    title: 'No matches',
                    body: 'Try a colour, a place, or a word from the description.',
                    icon: Icons.search_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: shown.length + (more ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == shown.length) {
                        return OutlinedButton(
                          onPressed: () =>
                              setState(() => _shown += listPageSize),
                          child: Text(
                            'Show more (${results.length - shown.length} left)',
                          ),
                        );
                      }
                      final item = shown[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
        ],
      ),
    );
  }

  Widget _menu(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButton<String>(
        value: options.containsKey(value) ? value : 'all',
        underline: const SizedBox.shrink(),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (next) => onChanged(next ?? 'all'),
      ),
    );
  }
}
