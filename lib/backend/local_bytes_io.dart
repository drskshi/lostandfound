import 'dart:io';

Future<List<int>?> readLocalBytes(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}
