import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';


/// Application detail / manual-add form (03_App_Flow.md §4.5, §6).
///
/// Route `/application/new` creates a manual entry; `/application/:id`
/// edits an existing tracker row with its status stepper.
class ApplicationFormScreen extends ConsumerStatefulWidget {
  const ApplicationFormScreen({super.key, this.applicationId});

  final String? applicationId;

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  // Manual-entry fields.
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _applyUrl = TextEditingController();

  // Tracker fields.
  final _cvVersion = TextEditingController();
  final _coverLetter = TextEditingController();
  final _notes = TextEditingController();

  ApplicationStatus _status = ApplicationStatus.planToApply;
  DateTime? _appliedAt;
  DateTime? _followUpAt;
  Application? _existing;
  Job? _job;
  bool _loaded = false;

  bool get _isManualCreate => widget.applicationId == null;

  @override
  void initState() {
    super.initState();
    if (!_isManualCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loaded = true;
    }
  }

  void _load() {
    final store = ref.read(storeProvider);
    final app = store.applicationById(widget.applicationId!);
    if (app == null) {
      setState(() => _loaded = true);
      return;
    }
    final job = app.jobId == null ? null : store.jobById(app.jobId!);
    _existing = app;
    _job = job;
    _status = app.status;
    _appliedAt = app.appliedAt;
    _followUpAt = app.followUpAt;
    _cvVersion.text = app.cvVersion ?? '';
    _coverLetter.text = app.coverLetter ?? '';
    _notes.text = app.notes ?? '';
    if (job != null && job.source == 'manual') {
      _title.text = job.title;
      _company.text = job.company;
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [
      _title, _company, _applyUrl, _cvVersion, _coverLetter, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool followUp}) async {
    final initial = (followUp ? _followUpAt : _appliedAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (followUp) {
        _followUpAt = picked;
      } else {
        _appliedAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final store = ref.read(storeProvider);
    if (_isManualCreate) {
      if (_title.text.trim().isEmpty || _company.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and company are required.')),
        );
        return;
      }
      final app = await store.addManualApplication(
        title: _title.text.trim(),
        company: _company.text.trim(),
        applyUrl: _applyUrl.text.trim(),
        status: _status,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      context.replace('/application/${app.id}');
      return;
    }

    final app = _existing!.copyWith(
      status: _status,
      appliedAt: _appliedAt,
      followUpAt: _followUpAt,
      cvVersion: _cvVersion.text.trim().isEmpty ? null : _cvVersion.text.trim(),
      coverLetter:
          _coverLetter.text.trim().isEmpty ? null : _coverLetter.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await store.updateApplication(app);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application updated.')),
    );
    context.pop();
  }

  void _onStatusTap(int index) {
    final status = ApplicationStatus.values[index];
    setState(() {
      _status = status;
      if (status == ApplicationStatus.applied && _appliedAt == null) {
        _appliedAt = DateTime.now();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ScoutColors.of(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isManualCreate && _existing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ScoutEmptyState(message: 'Application not found.'),
      );
    }

    final manualJob = _job?.source == 'manual';

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
                      Expanded(
                        child: Text(
                          _isManualCreate
                              ? 'Add manually'
                              : (_job?.title ?? 'Application'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!_isManualCreate && _job != null && !manualJob) ...[
                    ScoutCard(
                      onTap: () => context.push('/job/${_job!.id}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_job!.title,
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(_job!.company,
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ScoutCard(
                    inset: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ScoutSectionLabel('Status'),
                        ScoutStepper(
                          steps:
                              ApplicationStatus.values.map((s) => s.label).toList(),
                          currentIndex: ApplicationStatus.values.indexOf(_status),
                          onTap: _onStatusTap,
                        ),
                        const SizedBox(height: 18),
                        if (_isManualCreate) ...[
                          const ScoutSectionLabel('Job'),
                          ScoutInput(controller: _title, hint: 'Job title'),
                          const SizedBox(height: 12),
                          ScoutInput(controller: _company, hint: 'Company'),
                          const SizedBox(height: 12),
                          ScoutInput(
                            controller: _applyUrl,
                            hint: 'Apply / listing URL',
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 18),
                        ],
                        const ScoutSectionLabel('Dates'),
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Applied',
                                value: _appliedAt == null
                                    ? '—'
                                    : formatShortDate(_appliedAt!),
                                onTap: () => _pickDate(followUp: false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateField(
                                key: const ValueKey('follow-up-field'),
                                label: 'Follow up',
                                value: _followUpAt == null
                                    ? '—'
                                    : formatShortDate(_followUpAt!),
                                onTap: () => _pickDate(followUp: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const ScoutSectionLabel('CV version used'),
                        ScoutInput(
                            controller: _cvVersion, hint: 'e.g. cv-data-v2.pdf'),
                        const SizedBox(height: 18),
                        const ScoutSectionLabel('Cover letter'),
                        ScoutInput(
                          controller: _coverLetter,
                          hint: 'Draft or paste your cover letter…',
                          maxLines: 6,
                          minLines: 3,
                        ),
                        const SizedBox(height: 18),
                        const ScoutSectionLabel('Notes & interview details'),
                        ScoutInput(
                          controller: _notes,
                          hint: 'Interview dates, contacts, prep notes…',
                          maxLines: 6,
                          minLines: 3,
                        ),
                      ],
                    ),
                  ),
                  if (!_isManualCreate && manualJob) ...[
                    const SizedBox(height: 16),
                    ScoutButton(
                      onPressed: () async {
                        await ref
                            .read(storeProvider)
                            .deleteApplication(_existing!.id);
                        if (context.mounted) context.pop();
                      },
                      child: Text('Delete manual entry',
                          style: TextStyle(color: palette.muted)),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: palette.surface,
                boxShadow: [
                  BoxShadow(
                    color: palette.outlineVariant,
                    blurRadius: 14,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ScoutButton(
                key: const ValueKey('save-application'),
                filled: true,
                onPressed: _save,
                child: Text(_isManualCreate ? 'Add to tracker' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ScoutColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: palette.surfaceLow,
          borderRadius: BorderRadius.circular(ScoutRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 3),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(color: palette.primary)),
          ],
        ),
      ),
    );
  }
}
