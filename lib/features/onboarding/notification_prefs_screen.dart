import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
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
    await store.savePrefs(_prefs);
    await store.setOnboarded();
    if (!mounted) return;
    context.go('/discover');
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
                    NeuIconButton(
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
              NeuButton(
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
