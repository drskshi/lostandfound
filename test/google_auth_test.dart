import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_mobile/backend/google_auth.dart';
import 'package:lost_found_mobile/data/store.dart';

void main() {
  test('a new Google account stays a student', () {
    expect(roleFromServer(null), 'student');
    expect(roleFromServer('student'), 'student');
    expect(roleFromServer('owner'), 'student');
    expect(roleFromServer('ADMIN'), 'student');
    expect(roleFromServer('admin'), 'admin');
  });

  test('cancelled and network failures stay readable', () {
    expect(googleAuthError('access_denied'), 'Google sign-in was cancelled.');
    expect(
      googleAuthError('SocketException: failed host lookup'),
      'Google sign-in could not reach the network.',
    );
  });

  test('web and mobile callbacks are different', () {
    expect(googleRedirect(web: false), mobileAuthRedirect);
    expect(googleRedirect(web: true), webAuthOrigin);
  });

  test('the server profile role is what gets signed in', () {
    final store = CampusStore.demo();
    store.replaceSignedInAccount(
      id: 'google-user',
      email: 'student@example.test',
      name: 'Student',
      role: roleFromServer('student'),
      emailVerified: true,
      status: 'active',
    );
    expect(store.me?.role, 'student');
    expect(store.serverAccount, isTrue);
    expect(store.me?.passwordHash, isEmpty);
    store.signOut();
    expect(store.me, isNull);
    expect(store.serverAccount, isFalse);
  });
}
