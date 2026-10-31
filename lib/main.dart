import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app.dart';
import 'config/env.dart';
import 'data/app_store.dart';
import 'data/local_store.dart';
import 'data/providers.dart';
import 'data/push_notifications.dart';
import 'data/supabase/synced_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final local = await LocalStore.open();
  await local.removeBundledMockData();

  AppStore store = local;
  if (Env.isLiveConfigured) {
    // Phase 3: live backend. The app never calls job-source APIs directly —
    // fetch/normalize/dedup/score all happen server-side (see backend/).
    try {
      await sb.Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      final client = sb.Supabase.instance.client;
      await ensureSignedIn(client);
      final synced = SyncedStore(local, client);
      await synced.initialSync(); // offline-first cache warm-up
      try {
        final timeZone = await PushNotificationService.currentTimeZone();
        await synced.savePrefs(synced.prefs.copyWith(timeZone: timeZone));
      } catch (e) {
        debugPrint('RemoteScout: could not refresh device time zone — $e');
      }
      store = synced;
      if (Env.isFirebaseConfigured) {
        try {
          pushNotificationService =
              await PushNotificationService.configure(client);
        } catch (e) {
          debugPrint('RemoteScout: push notifications unavailable — $e');
        }
      }
      // Pull fresh scored listings in the background — the UI is already up.
      unawaited(synced.refresh());
    } catch (e) {
      // Backend unreachable at boot: keep serving the local cache (TRD §7).
      debugPrint('RemoteScout: Supabase unavailable, staying local — $e');
    }
  } else {
    // Local-only mode serves persisted user data without demo listings.
    await local.rescore();
  }

  appStore = store;
  runApp(const ProviderScope(child: RemoteScoutApp()));
}
