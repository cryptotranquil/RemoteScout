import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class PushNotificationService {
  PushNotificationService._(this._client, this._messaging);

  final SupabaseClient _client;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _permissionGranted = false;
  String? initialRoute;
  void Function(String route)? onRoute;

  static Future<PushNotificationService?> configure(
    SupabaseClient client,
  ) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        !Env.isFirebaseConfigured) {
      return null;
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        iosBundleId:
            Env.firebaseIosBundleId.isEmpty ? null : Env.firebaseIosBundleId,
      ),
    );

    final service =
        PushNotificationService._(client, FirebaseMessaging.instance);
    final settings = await service._messaging.getNotificationSettings();
    service._permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (service._permissionGranted) {
      try {
        final token = await service._messaging.getToken();
        if (token != null && token.isNotEmpty) await service._saveToken(token);
      } catch (error, stack) {
        developer.log(
          'Could not register existing FCM permission: $error',
          name: 'remotescout.notifications',
          stackTrace: stack,
        );
      }
    }
    final initialMessage = await service._messaging.getInitialMessage();
    service.initialRoute = _routeFromMessage(initialMessage);
    service._openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _routeFromMessage(message);
      if (route != null) service.onRoute?.call(route);
    });
    service._tokenSubscription =
        service._messaging.onTokenRefresh.listen((token) {
      if (!service._permissionGranted) return;
      service._saveToken(token).catchError((Object error, StackTrace stack) {
        developer.log(
          'Could not save refreshed FCM token: $error',
          name: 'remotescout.notifications',
          stackTrace: stack,
        );
      });
    });
    return service;
  }

  static Future<String> currentTimeZone() async =>
      FlutterTimezone.getLocalTimezone();

  Future<bool> requestPermissionAndRegister() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _permissionGranted = false;
      return false;
    }

    _permissionGranted = true;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase Messaging did not return a device token.');
    }
    await _saveToken(token);
    return true;
  }

  Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot register push token without a signed-in user.');
    }
    await _client.from('push_tokens').upsert(
      {
        'token': token,
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  static String? _routeFromMessage(RemoteMessage? message) {
    final Object? route = message?.data['route'];
    return route is String && (route == '/discover' || route == '/applications')
        ? route
        : null;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}

PushNotificationService? pushNotificationService;
