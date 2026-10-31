import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../data/push_notifications.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import 'notification_prefs_card.dart';

/// Notification preferences step (end of first-run) — 03_App_Flow.md §2.
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key, this.initialSetup = false});

  /// True when shown as the final onboarding step.
  final bool initialSetup;

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  NotificationPrefs _prefs = const NotificationPrefs();

  @override
  void initState() {
    super.initState();
    // Seed from the store when editing outside onboarding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.initialSetup) {
        setState(() => _prefs = ref.read(storeProvider).prefs);
      }
    });
  }

  Future<void> _finish() async {
    final store = ref.read(storeProvider);
    try {
      final timezone = await PushNotificationService.currentTimeZone();
      await store.savePrefs(_prefs.copyWith(timeZone: timezone));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not save notification preferences: $error')),
      );
      return;
    }
    await store.setOnboarded();
    var pushMessage = '';
    final push = pushNotificationService;
    if (push != null) {
      try {
        final enabled = await push.requestPermissionAndRegister();
        if (!enabled) {
          pushMessage = 'Push permission was not granted. You can enable it '
              'later in your device settings.';
        }
      } catch (error) {
        pushMessage = 'Could not register this device for push notifications: '
            '$error';
      }
    }
    if (!mounted) return;
    context.go('/discover');
    if (pushMessage.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pushMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.initialSetup)
                Row(
                  children: [
                    ScoutIconButton(
                      icon: Icons.close,
                      onPressed: () => context.pop(),
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Text('Notifications',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'One daily digest,\nnot constant pings.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Tune what "worth your time" means for you.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: NotificationPrefsCard(
                    prefs: _prefs,
                    onChanged: (p) => setState(() => _prefs = p),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ScoutButton(
                filled: true,
                key: const ValueKey('finish-setup'),
                onPressed: _finish,
                child: Text(widget.initialSetup ? 'Start scouting' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
