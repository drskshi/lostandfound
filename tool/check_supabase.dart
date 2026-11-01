import 'dart:convert';
import 'dart:io';

/// Checks the existing Supabase project without printing the publishable key.
///
/// Reads gitignored config/supabase.dev.json. Exit 0 is PASS, 1 is FAIL,
/// 2 is BLOCKED because the local config is missing.
Future<void> main() async {
  final file = File('config/supabase.dev.json');
  if (!file.existsSync()) {
    stderr.writeln(
      'BLOCKED: config/supabase.dev.json is missing. Copy config/supabase.dev.json.example and paste the project URL and publishable key from the Supabase dashboard.',
    );
    exit(2);
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('FAIL: config/supabase.dev.json must be a JSON object.');
    exit(1);
  }
  final url = (decoded['SUPABASE_URL'] as String? ?? '').trim();
  final key =
      (decoded['SUPABASE_PUBLISHABLE_KEY'] as String? ??
              decoded['SUPABASE_ANON_KEY'] as String? ??
              '')
          .trim();
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.host.endsWith('.supabase.co') ||
      key.length < 20 ||
      key.contains('YOUR_PUBLISHABLE_KEY')) {
    stderr.writeln(
      'BLOCKED: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is still a placeholder.',
    );
    exit(2);
  }

  final health = uri.replace(path: '/auth/v1/health', query: '');
  final client = HttpClient();
  try {
    final request = await client.getUrl(health);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('apikey', key);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    final response = await request.close().timeout(const Duration(seconds: 20));
    await response.drain<void>();
    stdout.writeln('host=${uri.host} auth_health=${response.statusCode}');
    if (response.statusCode == 200) {
      stdout.writeln(
        'PASS: Supabase auth endpoint accepted the publishable key.',
      );
      exit(0);
    }
    stderr.writeln('FAIL: auth health returned ${response.statusCode}.');
    exit(1);
  } on Exception catch (error) {
    stderr.writeln('FAIL: could not reach ${uri.host} (${error.runtimeType}).');
    exit(1);
  } finally {
    client.close(force: true);
  }
}
