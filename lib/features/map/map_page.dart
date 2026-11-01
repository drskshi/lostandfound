import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../theme/campus_theme.dart';
import '../shell/app_shell.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  String _type = 'all';
  bool _collection = false;
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final store = CampusScope.of(context);
    final places = store.myPlaces
        .where((place) => !_collection || place.collection)
        .toList();
    final items = store.visibleItems(type: _type);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus map'),
        actions: const [AccountMenuButton()],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      onSelected: (_) => setState(() => _type = type.$1),
                    ),
                  ),
                FilterChip(
                  label: const Text('Collection points'),
                  selected: _collection,
                  onSelected: (value) => setState(() => _collection = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _CampusPainter(),
                        ),
                        for (final place in places)
                          Positioned(
                            left: constraints.maxWidth * place.x / 100 - 18,
                            top: constraints.maxHeight * place.y / 100 - 18,
                            child: _Pin(
                              place: place,
                              count: items
                                  .where((item) => item.placeId == place.id)
                                  .length,
                              selected: _selected == place.id,
                              onTap: () => setState(() => _selected = place.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            height: 168,
            child: _selected == null
                ? const Center(child: Text('Tap a pin to see posts there.'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(
                        store.placeName(_selected),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(store.place(_selected)?.hours ?? ''),
                      const SizedBox(height: 8),
                      for (final item in items.where(
                        (item) => item.placeId == _selected,
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${item.colour} · ${item.type}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/items/${item.id}'),
                        ),
                      if (items
                          .where((item) => item.placeId == _selected)
                          .isEmpty)
                        TextButton(
                          onPressed: () => context.push('/items/new'),
                          child: const Text('Report something here'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.place,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final Place place;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${place.name}, $count posts',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? campusBlueDark : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: campusBlue),
              ),
              child: Text(
                '${place.shortName}${count == 0 ? '' : ' $count'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : campusBlueDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE7EEF8);
    canvas.drawRect(Offset.zero & size, bg);
    final grass = Paint()..color = const Color(0xFFD7E7D8);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.72), 70, grass);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.28), 54, grass);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.52);
    canvas.drawPath(path, road);
    final path2 = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.48, size.height);
    canvas.drawPath(path2, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
