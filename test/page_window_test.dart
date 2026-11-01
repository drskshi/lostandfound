import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_mobile/backend/backend_config.dart';
import 'package:lost_found_mobile/data/logic.dart';
import 'package:lost_found_mobile/data/store.dart';

void main() {
  test('page window grows without copying the whole list at once', () {
    final source = List<int>.generate(20, (index) => index);
    expect(pageWindow(source, 0), isEmpty);
    expect(pageWindow(source, listPageSize), [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(pageWindow(source, 100), source);
  });

  test('the first feed page still includes the newest sample posts', () {
    final store = CampusStore.demo();
    expect(store.signIn('amara@ravensbourne.example', demoPassword), isNull);
    final feed = store.feedItems();
    final first = pageWindow(feed, listPageSize);
    expect(first.length, listPageSize);
    expect(first.map((item) => item.id), contains('bottle'));
    expect(first.length, lessThan(feed.length));
  });

  test('backend config stays off until a real project URL is supplied', () {
    const empty = BackendConfig(url: '', publishableKey: '');
    const bad = BackendConfig(
      url: 'http://localhost:54321',
      publishableKey: 'short',
    );
    const ready = BackendConfig(
      url: 'https://exampleproject.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.example',
    );
    expect(empty.isConfigured, isFalse);
    expect(bad.isConfigured, isFalse);
    expect(ready.isConfigured, isTrue);
    expect(BackendConfig.fromEnvironment().isConfigured, isFalse);
  });
}
