import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'data/push_notifications.dart';
import 'data/providers.dart';
import 'router.dart';

/// RemoteScout — personal remote-job discovery and application assistant.
class RemoteScoutApp extends ConsumerStatefulWidget {
  const RemoteScoutApp({super.key});

  @override
  ConsumerState<RemoteScoutApp> createState() => _RemoteScoutAppState();
}

class _RemoteScoutAppState extends ConsumerState<RemoteScoutApp> {
  late final AppRouterRefresh _refresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _refresh = AppRouterRefresh(ref.read(storeProvider));
    _router = buildRouter(
      _refresh,
      initialLocation: pushNotificationService?.initialRoute,
    );
    pushNotificationService?.onRoute = _router.go;
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RemoteScout',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
