import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../data/app_store.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import 'profile_form.dart';

/// Multi-step profile setup (03_App_Flow.md §2). Step 3 is the scout-criteria
/// desk: roles, experience, compensation floor, geography and cadence.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 5;
  static const List<String> _stepNames = [
    'Profile',
    'Skills',
    'Criteria setup',
    'Location',
    'Links',
  ];

  int _step = 0;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _salary = TextEditingController();
  final _portfolio = TextEditingController();
  final _cv = TextEditingController();

  List<String> _roles = [];
  List<String> _skills = [];
  List<String> _timezones = [];
  bool _worldwideOnly = true;
  String _experience = 'junior';
  String _cadence = 'digest';

  @override
  void dispose() {
    for (final c in [_name, _email, _salary, _portfolio, _cv]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
    _saveProfileAndContinue();
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
  }

  Future<void> _saveProfileAndContinue() async {
    final store = ref.read(storeProvider);
    final now = DateTime.now();
    final salary = double.tryParse(
      _salary.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final profile = Profile(
      id: AppStore.userId,
      name: _name.text.trim(),
      email: _email.text.trim(),
      skills: _skills,
      targetRoles: _roles,
      minimumSalary: salary,
      preferredCountries: _worldwideOnly ? const ['worldwide'] : const [],
      preferredTimezones: _timezones,
      experienceLevel: _experience,
      cvUrl: _cv.text.trim().isEmpty ? null : _cv.text.trim(),
      portfolioUrl:
          _portfolio.text.trim().isEmpty ? null : _portfolio.text.trim(),
      createdAt: now,
    );
    await store.saveProfile(profile);
    await store.savePrefs(
      NotificationPrefs(
        minMatchScore: _cadence == 'digest' ? 70 : 90,
        maxJobsPerDay: 5,
      ),
    );
    if (!mounted) return;
    await context.push('/notifications-setup');
  }

  String get _stepTitle => switch (_step) {
        0 => 'Who are you scouting as?',
        1 => 'What tools do you know?',
        2 => 'Define your scout criteria',
        3 => 'Where can you work from?',
        _ => 'Almost done — your links',
      };

  String get _stepHint => switch (_step) {
        0 => 'Pick the roles you would genuinely apply for.',
        1 => 'These are matched against every posting we crawl.',
        2 => 'Set the floor for what reaches you.',
        3 => 'Used to score timezone overlap on every listing.',
        _ => 'Optional — kept private on this device.',
      };

  Widget _stepBody(BuildContext context) {
    final store = ref.watch(storeProvider);
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScoutSectionLabel('About you'),
            ScoutInput(
              controller: _name,
              hint: 'Your name',
            ),
            const SizedBox(height: ScoutSpace.sm),
            ScoutInput(
              controller: _email,
              hint: 'Email (optional — for the digest)',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: ScoutSpace.lg),
            const ScoutSectionLabel('Target roles'),
            ChipsField(
              key: const ValueKey('roles-field'),
              selected: _roles,
              onChanged: (v) => setState(() => _roles = v),
              suggestions: ProfileFormFields.roleSuggestions,
              hint: 'Add a role…',
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScoutSectionLabel('Skills'),
            ChipsField(
              key: const ValueKey('skills-field'),
              selected: _skills,
              onChanged: (v) => setState(() => _skills = v),
              suggestions: ProfileFormFields.skillSuggestions,
              hint: 'Add a skill…',
            ),
          ],
        );
      case 2:
        final matching = store.allJobs.where((job) {
          if (_roles.isEmpty) return true;
          final title = job.title.toLowerCase();
          return _roles.any((role) => title.contains(role.toLowerCase()));
        }).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ScoutSpace.md,
                vertical: ScoutSpace.sm,
              ),
              decoration: BoxDecoration(
                color: ScoutColors.of(context).surfaceLow,
                borderRadius: BorderRadius.circular(ScoutRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(Icons.radar,
                      size: 18, color: ScoutColors.of(context).primary),
                  const SizedBox(width: ScoutSpace.sm),
                  Expanded(
                    child: Text(
                      'Estimated live pipeline',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  ScoutBadge(
                    label: '$matching matching roles',
                    tone: ScoutBadgeTone.soft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ScoutSpace.md),
            const ScoutSectionLabel('Target roles'),
            Wrap(
              spacing: ScoutSpace.xs + 2,
              runSpacing: ScoutSpace.xs + 2,
              children: [
                for (final role in ProfileFormFields.roleSuggestions.take(5))
                  ScoutFilterPill(
                    label: role,
                    icon: _roles.contains(role) ? Icons.check : Icons.add,
                    selected: _roles.contains(role),
                    onTap: () => setState(() {
                      final next = [..._roles];
                      if (next.contains(role)) {
                        next.remove(role);
                      } else {
                        next.add(role);
                      }
                      _roles = next;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: ScoutSpace.md),
            const ScoutSectionLabel('Experience level'),
            _SelectTile(
              title: 'Entry-level (0–2 yrs)',
              trailing: 'Standard',
              selected: _experience == 'entry',
              onTap: () => setState(() => _experience = 'entry'),
            ),
            const SizedBox(height: ScoutSpace.xs + 2),
            _SelectTile(
              title: 'Junior (1–3 yrs)',
              trailing: _experience == 'junior' ? 'Selected' : 'Recommended',
              selected: _experience == 'junior',
              onTap: () => setState(() => _experience = 'junior'),
            ),
            const SizedBox(height: ScoutSpace.xs + 2),
            _SelectTile(
              title: 'Associate (2–4 yrs)',
              trailing: 'Stretch',
              selected: _experience == 'associate',
              onTap: () => setState(() => _experience = 'associate'),
            ),
            const SizedBox(height: ScoutSpace.md),
            Row(
              children: [
                const Expanded(child: ScoutSectionLabel('Compensation floor')),
                Text(
                  'Strict cutoff',
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: ScoutColors.of(context).primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: ScoutSpace.xs),
            ScoutInput(
              key: const ValueKey('salary-floor'),
              controller: _salary,
              hint: 'e.g. 28000 USD / year',
              prefixIcon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: ScoutSpace.md),
            const ScoutSectionLabel('Remote & geographic constraints'),
            _SelectTile(
              title: '100% anywhere remote',
              subtitle: 'Global contract or entity anywhere',
              trailingIcon: Icons.public,
              selected: _worldwideOnly,
              onTap: () => setState(() => _worldwideOnly = true),
            ),
            const SizedBox(height: ScoutSpace.xs + 2),
            _SelectTile(
              title: 'Region-restricted only',
              subtitle: 'Timezone overlap required by the employer',
              trailingIcon: Icons.schedule,
              selected: !_worldwideOnly,
              onTap: () => setState(() => _worldwideOnly = false),
            ),
            const SizedBox(height: ScoutSpace.md),
            const ScoutSectionLabel('Notification & scout cadence'),
            _SelectTile(
              title: 'One calm morning digest',
              subtitle: 'Shortlist at 08:30 · zero midday interruptions',
              trailing: 'Recommended',
              selected: _cadence == 'digest',
              onTap: () => setState(() => _cadence = 'digest'),
            ),
            const SizedBox(height: ScoutSpace.xs + 2),
            _SelectTile(
              title: 'Real-time alerts for ≥90% matches',
              subtitle: 'Only when high-signal criteria are met',
              selected: _cadence == 'realtime',
              onTap: () => setState(() => _cadence = 'realtime'),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScoutSectionLabel('Location eligibility'),
            Wrap(
              spacing: ScoutSpace.xs + 2,
              runSpacing: ScoutSpace.xs + 2,
              children: [
                ScoutFilterPill(
                  label: 'Worldwide remote',
                  selected: _worldwideOnly,
                  onTap: () => setState(() => _worldwideOnly = !_worldwideOnly),
                ),
                ScoutFilterPill(
                  label: 'Region-restricted',
                  selected: !_worldwideOnly,
                  onTap: () => setState(() => _worldwideOnly = !_worldwideOnly),
                ),
              ],
            ),
            const SizedBox(height: ScoutSpace.lg),
            const ScoutSectionLabel('Preferred time zones (optional)'),
            ChipsField(
              key: const ValueKey('timezones-field'),
              selected: _timezones,
              onChanged: (v) => setState(() => _timezones = v),
              suggestions: ProfileFormFields.timezoneSuggestions,
              hint: 'Add a time zone…',
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScoutSectionLabel('Portfolio link (optional)'),
            ScoutInput(
              controller: _portfolio,
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: ScoutSpace.lg),
            const ScoutSectionLabel('CV link (optional)'),
            ScoutInput(
              controller: _cv,
              hint: 'Link to your CV',
              keyboardType: TextInputType.url,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final percent = ((_step + 1) / _stepCount * 100).round();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScoutAppHeader(
              title: 'Criteria setup',
              onBack: _back,
              avatarName: ref.watch(profileProvider).valueOrNull?.name,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  ScoutSpace.lg,
                  ScoutSpace.xs,
                  ScoutSpace.lg,
                  ScoutSpace.xl,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'STEP ${_step + 1} OF $_stepCount • ${_stepNames[_step].toUpperCase()}',
                          style: text.labelMedium!.copyWith(
                            color: colors.muted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        '$percent% complete',
                        style: text.labelMedium!.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ScoutSpace.sm),
                  ScoutStepProgress(total: _stepCount, current: _step),
                  const SizedBox(height: ScoutSpace.lg),
                  Text(_stepTitle, style: text.headlineSmall),
                  const SizedBox(height: 2),
                  Text(_stepHint, style: text.bodySmall),
                  const SizedBox(height: ScoutSpace.lg),
                  _stepBody(context),
                  const SizedBox(height: ScoutSpace.xl),
                  Row(
                    children: [
                      ScoutButton(
                        label: 'Back',
                        expand: false,
                        onPressed: _back,
                      ),
                      const SizedBox(width: ScoutSpace.sm),
                      Expanded(
                        child: ScoutButton(
                          key: const ValueKey('onboarding-next'),
                          label: _step == _stepCount - 1
                              ? 'Save & generate recommendations'
                              : 'Next',
                          trailingIcon: _step == _stepCount - 1
                              ? Icons.arrow_forward
                              : null,
                          variant: ScoutButtonVariant.primary,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ScoutSpace.sm),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Your data stays on device. RemoteScout never contacts '
                          'recruiters without your explicit action.',
                          style: text.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radio-style tile used by the criteria step.
class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.trailingIcon,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? trailingIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(ScoutSpace.md),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceHighest : colors.surfaceLow,
          borderRadius: BorderRadius.circular(ScoutRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.brandFill : colors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? Icon(Icons.check, size: 13, color: colors.onBrand)
                  : null,
            ),
            const SizedBox(width: ScoutSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyMedium!.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) Text(subtitle!, style: text.labelSmall),
                ],
              ),
            ),
            if (trailing != null)
              ScoutBadge(
                label: trailing!,
                tone: selected ? ScoutBadgeTone.soft : ScoutBadgeTone.tonal,
              ),
            if (trailingIcon != null)
              Icon(
                trailingIcon,
                size: 18,
                color: selected ? colors.primary : colors.outline,
              ),
          ],
        ),
      ),
    );
  }
}
