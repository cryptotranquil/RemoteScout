import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../data/app_store.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import 'profile_form.dart';

/// Multi-step profile setup (03_App_Flow.md §2, steps 1–6).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 6;
  int _step = 0;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _salary = TextEditingController();
  final _portfolio = TextEditingController();
  final _cv = TextEditingController();

  List<String> _roles = [];
  List<String> _skills = [];
  List<String> _timezones = [];
  List<String> _countries = ['worldwide'];
  String _experience = 'junior';

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
    final profile = Profile(
      id: AppStore.userId,
      name: _name.text.trim(),
      email: _email.text.trim(),
      skills: _skills,
      targetRoles: _roles,
      minimumSalary: double.tryParse(_salary.text.trim()),
      preferredCountries: _countries,
      preferredTimezones: _timezones,
      experienceLevel: _experience,
      cvUrl: _cv.text.trim().isEmpty ? null : _cv.text.trim(),
      portfolioUrl: _portfolio.text.trim().isEmpty ? null : _portfolio.text.trim(),
      createdAt: now,
    );
    await store.saveProfile(profile);
    if (!mounted) return;
    await context.push('/notifications-setup');
  }

  String get _stepTitle => switch (_step) {
        0 => 'Who are you scouting as?',
        1 => 'What tools do you know?',
        2 => 'What is your experience level?',
        3 => 'Where can you work from?',
        4 => 'Compensation & time zones',
        _ => 'Almost done — your links',
      };

  String get _stepHint => switch (_step) {
        0 => 'Pick the roles you would genuinely apply for.',
        1 => 'These are matched against each job listing.',
        2 => 'We favour junior and entry-level friendly listings.',
        3 => 'Worldwide-remote is your confirmed default.',
        4 => 'Optional — used to filter and explain matches.',
        _ => 'Optional — kept private on this device (for now).',
      };

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NeuSectionLabel('About you'),
            NeuInput(controller: _name, hint: 'Your name'),
            const SizedBox(height: 12),
            NeuInput(
              controller: _email,
              hint: 'Email (optional — for the email digest)',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),
            const NeuSectionLabel('Target roles'),
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
            const NeuSectionLabel('Skills'),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NeuSectionLabel('Experience level'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final level in const ['junior', 'entry', 'associate'])
                  NeuPill(
                    label: switch (level) {
                      'junior' => 'Junior',
                      'entry' => 'Entry-level',
                      _ => 'Associate',
                    },
                    selected: _experience == level,
                    onTap: () => setState(() => _experience = level),
                  ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NeuSectionLabel('Location eligibility'),
            const LocationBadge(
              scope: 'worldwide',
              detail: 'Worldwide-remote roles only — no fixed country restriction',
            ),
            const SizedBox(height: 14),
            Wrap(
              children: [
                NeuPill(
                  label: 'Worldwide remote',
                  selected: _countries.contains('worldwide'),
                  onTap: () => setState(() {
                    _countries =
                        _countries.contains('worldwide') ? [] : ['worldwide'];
                  }),
                ),
              ],
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NeuSectionLabel('Minimum salary (optional)'),
            NeuInput(
              controller: _salary,
              hint: 'e.g. 24000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            const NeuSectionLabel('Preferred time zones (optional)'),
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
            const NeuSectionLabel('Portfolio link (optional)'),
            NeuInput(
              controller: _portfolio,
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 18),
            const NeuSectionLabel('CV link (optional)'),
            NeuInput(
              controller: _cv,
              hint: 'Link to your CV (file upload arrives with Supabase in Phase 3)',
              keyboardType: TextInputType.url,
            ),
          ],
        );
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
              Row(
                children: [
                  NeuIconButton(
                    icon: Icons.arrow_back,
                    onPressed: _back,
                    size: 46,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: NeuProgressDots(total: _stepCount, current: _step)),
                ],
              ),
              const SizedBox(height: 24),
              Text(_stepTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(_stepHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: NeuCard(
                    inset: true,
                    child: _stepBody(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              NeuButton(
                filled: true,
                key: const ValueKey('onboarding-next'),
                onPressed: _next,
                child: Text(_step == _stepCount - 1 ? 'Continue' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
