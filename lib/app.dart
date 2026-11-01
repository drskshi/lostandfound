import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/store.dart';
import 'routing/app_router.dart';
import 'theme/campus_theme.dart';

class CampusScope extends InheritedNotifier<CampusStore> {
  const CampusScope({
    required CampusStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static CampusStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CampusScope>();
    assert(scope != null, 'CampusScope is missing');
    return scope!.notifier!;
  }
}

class LostFoundApp extends StatefulWidget {
  const LostFoundApp({super.key, required this.store});
  final CampusStore store;

  @override
  State<LostFoundApp> createState() => _LostFoundAppState();
}

class _LostFoundAppState extends State<LostFoundApp> {
  late final GoRouter _router = buildRouter(widget.store);

  @override
  Widget build(BuildContext context) {
    return CampusScope(
      store: widget.store,
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => MaterialApp.router(
          title: 'Lost & Found',
          debugShowCheckedModeBanner: false,
          theme: campusLight(),
          darkTheme: campusDark(),
          themeMode: widget.store.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
