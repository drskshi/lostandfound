import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

/// Starts Supabase only when a publishable key was provided at build time.
/// The existing router and on-phone store keep working when it is absent.
class SupabaseBootstrap {
  static bool isReady = false;

  static Future<void> start() async {
    final config = BackendConfig.fromEnvironment();
    if (!config.isConfigured) return;
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
      );
      isReady = true;
    } catch (error) {
      debugPrint('Supabase did not start. The on-phone store is still in use.');
    }
  }
}
