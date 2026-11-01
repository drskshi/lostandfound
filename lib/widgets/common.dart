import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../data/store.dart';

export '../data/store.dart' show formatDate, formatWhen, statusLabel;
import '../theme/campus_theme.dart';

class CampusLogo extends StatelessWidget {
  const CampusLogo({super.key, this.size = 36, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white : campusBlue,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(
            Icons.search,
            color: light ? campusBlue : Colors.white,
            size: size * 0.62,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Lost & Found',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: size * 0.48,
            color: light
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.radius = 22});
  final Person? person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Color(person?.tone ?? 0xFF285DE5);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      foregroundColor: color,
      child: Text(
        person?.initials ?? '?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.7),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = 'neutral'});
  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      'found' => (const Color(0xFFE5F6EF), const Color(0xFF17664D)),
      'lost' => (const Color(0xFFFFF3E4), const Color(0xFF946015)),
      'bad' => (const Color(0xFFFDECEA), const Color(0xFFB42318)),
      'good' => (const Color(0xFFE8F5EC), const Color(0xFF15803D)),
      'info' => (campusSoft, campusBlueDark),
      _ => (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.onSurface,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: campusBlue),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.68),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class ItemArtwork extends StatelessWidget {
  const ItemArtwork({super.key, required this.item, this.height = 180});
  final CampusItem item;
  final double height;

  @override
  Widget build(BuildContext context) {
    final file = item.photoPath;
    if (file != null && file.startsWith('https://')) {
      return Image.network(
        file,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: item.title,
        errorBuilder: (context, error, stack) => _placeholder(),
      );
    }
    if (file != null && File(file).existsSync()) {
      return Image.file(
        File(file),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: item.title,
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final color = _categoryColor(item.category);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _categoryIcon(item.category),
            color: Colors.white,
            size: height > 120 ? 48 : 32,
          ),
          if (height > 120) ...[
            const SizedBox(height: 8),
            Text(
              item.category,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.place,
    required this.author,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });
  final CampusItem item;
  final String place;
  final Person? author;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ItemArtwork(item: item, height: 168),
                Positioned(
                  left: 12,
                  top: 12,
                  child: StatusPill(
                    label: item.type == 'found' ? 'Found' : 'Lost',
                    tone: item.type == 'found' ? 'found' : 'lost',
                  ),
                ),
                if (item.status != 'open')
                  Positioned(
                    right: 12,
                    top: 12,
                    child: StatusPill(
                      label: statusLabel(item.status),
                      tone: item.status == 'returned' ? 'good' : 'info',
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: IconButton.filledTonal(
                    tooltip: saved ? 'Remove saved post' : 'Save post',
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$place · ${item.colour} · ${formatWhen(item.createdAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.62),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      PersonAvatar(person: author, radius: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          author?.name ?? 'Campus member',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.likeCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineTile extends StatelessWidget {
  const TimelineTile({
    super.key,
    required this.title,
    this.detail,
    required this.time,
    required this.last,
  });
  final String title;
  final String? detail;
  final String time;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: campusBlue,
                shape: BoxShape.circle,
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 48,
                color: campusBlue.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.7),
                      height: 1.35,
                    ),
                  ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<String?> pickCampusPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 74,
    );
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/uploads');
    await folder.create(recursive: true);
    final dest = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await File(picked.path).copy(dest.path);
    return dest.path;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't read that photo.")),
      );
    }
    return null;
  }
}

void showGoogleNotice(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Google sign-in',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'The button is ready, but this project has no Google Cloud OAuth client yet. Sign-in with Google is not connected on Android or iOS. Use email on this phone for now.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Electronics' => Icons.headphones,
    'Bags' => Icons.backpack_outlined,
    'Bottles & cups' => Icons.water_drop_outlined,
    'Keys' => Icons.vpn_key_outlined,
    'Clothing' => Icons.checkroom_outlined,
    'Books & stationery' => Icons.menu_book_outlined,
    _ => Icons.category_outlined,
  };
}

Color _categoryColor(String category) {
  return switch (category) {
    'Electronics' => const Color(0xFF285DE5),
    'Bags' => const Color(0xFF5C6B82),
    'Bottles & cups' => const Color(0xFF17664D),
    'Keys' => const Color(0xFF946015),
    'Clothing' => const Color(0xFF7A5AF8),
    'Books & stationery' => const Color(0xFF1948BC),
    _ => const Color(0xFFC45C78),
  };
}
