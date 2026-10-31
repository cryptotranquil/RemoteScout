import 'package:flutter/material.dart';

import '../../core/ui/scout_ui.dart';
import '../../models/models.dart';

/// Notification preferences card (onboarding + Profile) — PRD §6.5:
/// digest time, min match score, max jobs/day, weekend on/off toggle.
class NotificationPrefsCard extends StatelessWidget {
  const NotificationPrefsCard({
    super.key,
    required this.prefs,
    required this.onChanged,
  });

  final NotificationPrefs prefs;
  final ValueChanged<NotificationPrefs> onChanged;

  TimeOfDay get _digestAsTime {
    final parts = prefs.digestTime.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _digestAsTime,
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    onChanged(prefs.copyWith(digestTime: '$hh:$mm'));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScoutColors.of(context);
    final labelStyle = Theme.of(context).textTheme.bodyMedium!;
    final valueStyle = Theme.of(context).textTheme.titleSmall!;

    return ScoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScoutSectionLabel('Daily digest'),
          Row(
            children: [
              Expanded(child: Text('Digest time', style: labelStyle)),
              GestureDetector(
                key: const ValueKey('digest-time'),
                onTap: () => _pickTime(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: palette.surfaceContainer,
                    borderRadius: BorderRadius.circular(ScoutRadius.sm),
                  ),
                  child: Text(
                    formatDigestTime(prefs.digestTime),
                    style: valueStyle.copyWith(color: palette.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Local time · ${prefs.timeZone}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Text('Minimum match score  ·  ${prefs.minMatchScore}%',
              style: labelStyle),
          Slider(
            value: prefs.minMatchScore.toDouble().clamp(0, 100),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: Scout.primary,
            inactiveColor: palette.track,
            onChanged: (v) =>
                onChanged(prefs.copyWith(minMatchScore: v.round())),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Max jobs per day', style: labelStyle)),
              _StepperControl(
                value: prefs.maxJobsPerDay,
                onMinus: () => onChanged(prefs.copyWith(
                    maxJobsPerDay:
                        prefs.maxJobsPerDay > 1 ? prefs.maxJobsPerDay - 1 : 1)),
                onPlus: () => onChanged(prefs.copyWith(
                    maxJobsPerDay: prefs.maxJobsPerDay < 15
                        ? prefs.maxJobsPerDay + 1
                        : 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Weekend digests', style: labelStyle)),
              ScoutSwitch(
                value: prefs.weekendEnabled,
                onChanged: (v) => onChanged(prefs.copyWith(weekendEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'One digest a day — no per-job pings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String formatDigestTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute.toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScoutIconButton(icon: Icons.remove, onPressed: onMinus, size: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$value', style: Theme.of(context).textTheme.titleSmall),
        ),
        ScoutIconButton(icon: Icons.add, onPressed: onPlus, size: 44),
      ],
    );
  }
}
