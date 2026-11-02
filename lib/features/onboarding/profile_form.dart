import 'package:flutter/material.dart';

import '../../core/ui/scout_ui.dart';

/// Multi-select chip field with suggestions + free entry
/// (target roles, skills, time zones in onboarding/profile).
class ChipsField extends StatefulWidget {
  const ChipsField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.suggestions = const [],
    this.hint = 'Add…',
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String hint;

  @override
  State<ChipsField> createState() => _ChipsFieldState();
}

class _ChipsFieldState extends State<ChipsField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    final next = [...widget.selected];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    widget.onChanged(next);
  }

  void _addFreeText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!widget.selected.contains(text)) {
      widget.onChanged([...widget.selected, text]);
    }
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScoutColors.of(context);
    final extras =
        widget.suggestions.where((s) => !widget.selected.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in widget.selected)
                GestureDetector(
                  key: ValueKey('chip-$value'),
                  onTap: () => _toggle(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(minHeight: 40),
                    decoration: BoxDecoration(
                      color: palette.surfaceContainer,
                      borderRadius: BorderRadius.circular(ScoutRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium!
                                .copyWith(
                                  color: palette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.close, size: 14, color: palette.muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (extras.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in extras)
                ScoutFilterPill(
                  key: ValueKey('suggestion-$value'),
                  label: value,
                  selected: false,
                  onTap: () => _toggle(value),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: ScoutInput(
                controller: _controller,
                hint: widget.hint,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addFreeText(),
              ),
            ),
            const SizedBox(width: 10),
            ScoutIconButton(
              key: const ValueKey('chip-add'),
              icon: Icons.add,
              onPressed: _addFreeText,
              size: 48,
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared profile form (onboarding steps and Edit Profile) — PRD §6.1.
class ProfileFormFields extends StatelessWidget {
  const ProfileFormFields({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.roles,
    required this.skills,
    required this.experienceLevel,
    required this.preferredCountries,
    required this.timezones,
    required this.salaryController,
    required this.portfolioController,
    required this.cvController,
    required this.onRolesChanged,
    required this.onSkillsChanged,
    required this.onExperienceChanged,
    required this.onCountriesChanged,
    required this.onTimezonesChanged,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final List<String> roles;
  final List<String> skills;
  final String experienceLevel;
  final List<String> preferredCountries;
  final List<String> timezones;
  final TextEditingController salaryController;
  final TextEditingController portfolioController;
  final TextEditingController cvController;
  final ValueChanged<List<String>> onRolesChanged;
  final ValueChanged<List<String>> onSkillsChanged;
  final ValueChanged<String> onExperienceChanged;
  final ValueChanged<List<String>> onCountriesChanged;
  final ValueChanged<List<String>> onTimezonesChanged;

  static const List<String> roleSuggestions = [
    'Junior Data Analyst',
    'Data Analyst Intern',
    'Junior Business Analyst',
    'Junior BI Analyst',
    'Reporting Analyst',
    'Data Technician',
    'Junior Marketing Analyst',
    'Junior Operations Analyst',
  ];

  static const List<String> skillSuggestions = [
    'SQL',
    'Excel',
    'Google Sheets',
    'Tableau',
    'Power BI',
    'Looker',
    'Python',
    'R',
    'Statistics',
    'Data Cleaning',
  ];

  static const List<String> timezoneSuggestions = [
    'UTC',
    'UTC+2',
    'CET',
    'ET (UTC-5)',
    'Flexible',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScoutSectionLabel('About you'),
        ScoutInput(controller: nameController, hint: 'Your name'),
        const SizedBox(height: 12),
        ScoutInput(
          controller: emailController,
          hint: 'Email (for the optional email digest)',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Target roles'),
        ChipsField(
          key: const ValueKey('roles-field'),
          selected: roles,
          onChanged: onRolesChanged,
          suggestions: roleSuggestions,
          hint: 'Add a role…',
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Skills'),
        ChipsField(
          key: const ValueKey('skills-field'),
          selected: skills,
          onChanged: onSkillsChanged,
          suggestions: skillSuggestions,
          hint: 'Add a skill…',
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Experience level'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final level in const ['junior', 'entry', 'associate'])
              ScoutFilterPill(
                label: switch (level) {
                  'junior' => 'Junior',
                  'entry' => 'Entry-level',
                  _ => 'Associate',
                },
                selected: experienceLevel == level,
                onTap: () => onExperienceChanged(level),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Location eligibility'),
        const ScoutLocationBadge(
          scope: 'worldwide',
          detail: 'Worldwide-remote roles only (no fixed country restriction)',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ScoutFilterPill(
              label: 'Worldwide remote',
              selected: preferredCountries.contains('worldwide'),
              onTap: () => onCountriesChanged(
                preferredCountries.contains('worldwide') ? [] : ['worldwide'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Minimum salary (optional)'),
        ScoutInput(
          controller: salaryController,
          hint: 'e.g. 24000',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Preferred time zones (optional)'),
        ChipsField(
          key: const ValueKey('timezones-field'),
          selected: timezones,
          onChanged: onTimezonesChanged,
          suggestions: timezoneSuggestions,
          hint: 'Add a time zone…',
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('Portfolio link (optional)'),
        ScoutInput(
          controller: portfolioController,
          hint: 'https://…',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 18),
        const ScoutSectionLabel('CV link (optional)'),
        ScoutInput(
          controller: cvController,
          hint:
              'Link to your CV (file upload arrives with Supabase in Phase 3)',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }
}
