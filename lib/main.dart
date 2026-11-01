import 'package:flutter/material.dart';

import 'app.dart';
import 'backend/google_auth.dart';
import 'backend/supabase_bootstrap.dart';
import 'backend/url_strategy.dart';
import 'data/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrl();
  await SupabaseBootstrap.start();
  final store = CampusStore();
  await store.init();
  await GoogleAuth.bind(store);
  runApp(LostFoundApp(store: store));
}
