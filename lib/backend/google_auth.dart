import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/store.dart';
import '../domain/access_role.dart';
import 'campus_remote.dart';
import 'supabase_bootstrap.dart';

/// Mobile callback. Add this exact value in Supabase redirect URLs.
const mobileAuthRedirect = 'com.powerrangers.lostfound://login-callback';

/// Web builds use a fixed port so the redirect URL can be allow-listed.
const webAuthOrigin = 'http://localhost:3000';

String googleRedirect({required bool web}) => web ? webAuthOrigin : mobileAuthRedirect;

/// Ignores any role supplied by the sign-in screen. Unknown values stay students.
String roleFromServer(String? role) {
  switch (parseAccessRole(role)) {
    case AccessRole.superadmin:
      return 'superadmin';
    case AccessRole.admin:
      return 'admin';
    case AccessRole.subadmin:
      return 'subadmin';
    case AccessRole.student:
    case null:
      return 'student';
  }
}

String googleAuthError(String message) {
  final text = message.toLowerCase();
  if (text.contains('cancel') ||
      text.contains('access_denied') ||
      text.contains('user closed')) {
    return 'Google sign-in was cancelled.';
  }
  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('timed out') ||
      text.contains('failed host')) {
    return 'Google sign-in could not reach the network.';
  }
  return 'Google sign-in did not finish. Try again.';
}

class GoogleAuth {
  static bool _bound = false;

  static Future<void> bind(CampusStore store) async {
    if (_bound || !SupabaseBootstrap.isReady) return;
    _bound = true;
    store.endServerSession = signOut;
    final auth = Supabase.instance.client.auth;
    auth.onAuthStateChange.listen((event) async {
      final session = event.session;
      if (session == null) {
        if (store.serverAccount) store.clearServerSession();
        return;
      }
      await _apply(store, session.user);
    });
    final current = auth.currentSession;
    if (current != null) {
      await _apply(store, current.user);
    } else if (store.serverAccount) {
      store.clearServerSession();
    }
  }

  static Future<String?> start() async {
    if (!SupabaseBootstrap.isReady) {
      return 'Google sign-in needs a build that includes the shared database.';
    }
    try {
      final opened = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleRedirect(web: kIsWeb),
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) return 'Google sign-in did not open.';
      return null;
    } on AuthException catch (error) {
      return googleAuthError(error.message);
    } catch (error) {
      debugPrint('Google sign-in failed: ${error.runtimeType}');
      return googleAuthError(error.toString());
    }
  }

  static Future<void> signOut() async {
    if (!SupabaseBootstrap.isReady) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      debugPrint('Sign-out did not reach Supabase: ${error.runtimeType}');
    }
  }

  static Future<void> _apply(CampusStore store, User user) async {
    await CampusRemote.adopt(store, user);
  }
}
