import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../data/providers.dart';
import '../onboarding/profile_form.dart';

/// Editable version of the onboarding profile form (PRD §6.1).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
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
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(storeProvider).profile;
      if (profile != null) {
        _name.text = profile.name;
        _email.text = profile.email;
        _salary.text =
            profile.minimumSalary == null ? '' : profile.minimumSalary!.round().toString();
        _portfolio.text = profile.portfolioUrl ?? '';
        _cv.text = profile.cvUrl ?? '';
        _roles = [...profile.targetRoles];
        _skills = [...profile.skills];
        _timezones = [...profile.preferredTimezones];
        _countries = [...profile.preferredCountries];
        _experience = profile.experienceLevel;
      }
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _salary, _portfolio, _cv]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final store = ref.read(storeProvider);
    final current = store.profile;
    if (current == null) return;
    final updated = current.copyWith(
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
    );
    await store.saveProfile(updated); // re-scores matches automatically
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Row(
                    children: [
                      ScoutIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => context.pop(),
                        size: 46,
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 14),
                      Text('Edit profile',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ScoutCard(
                    inset: true,
                    child: ProfileFormFields(
                      nameController: _name,
                      emailController: _email,
                      roles: _roles,
                      skills: _skills,
                      experienceLevel: _experience,
                      preferredCountries: _countries,
                      timezones: _timezones,
                      salaryController: _salary,
                      portfolioController: _portfolio,
                      cvController: _cv,
                      onRolesChanged: (v) => setState(() => _roles = v),
                      onSkillsChanged: (v) => setState(() => _skills = v),
                      onExperienceChanged: (v) => setState(() => _experience = v),
                      onCountriesChanged: (v) => setState(() => _countries = v),
                      onTimezonesChanged: (v) => setState(() => _timezones = v),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: ScoutColors.of(context).card,
                border: Border(
                  top: BorderSide(
                    color: ScoutColors.of(context).outlineVariant,
                  ),
                ),
              ),
              child: ScoutButton(
                key: const ValueKey('save-profile'),
                filled: true,
                onPressed: _save,
                child: const Text('Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
