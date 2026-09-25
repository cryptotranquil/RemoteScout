import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

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
    final palette = NeuPalette.of(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isManualCreate && _existing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(message: 'Application not found.'),
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
                      NeuIconButton(
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
                    NeuCard(
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
                  NeuCard(
                    inset: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NeuSectionLabel('Status'),
                        NeuStepper(
                          steps:
                              ApplicationStatus.values.map((s) => s.label).toList(),
                          currentIndex: ApplicationStatus.values.indexOf(_status),
                          onTap: _onStatusTap,
                        ),
                        const SizedBox(height: 18),
                        if (_isManualCreate) ...[
                          const NeuSectionLabel('Job'),
                          NeuInput(controller: _title, hint: 'Job title'),
                          const SizedBox(height: 12),
                          NeuInput(controller: _company, hint: 'Company'),
                          const SizedBox(height: 12),
                          NeuInput(
                            controller: _applyUrl,
                            hint: 'Apply / listing URL',
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 18),
                        ],
                        const NeuSectionLabel('Dates'),
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
                        const NeuSectionLabel('CV version used'),
                        NeuInput(
                            controller: _cvVersion, hint: 'e.g. cv-data-v2.pdf'),
                        const SizedBox(height: 18),
                        const NeuSectionLabel('Cover letter'),
                        NeuInput(
                          controller: _coverLetter,
                          hint: 'Draft or paste your cover letter…',
                          maxLines: 6,
                          minLines: 3,
                        ),
                        const SizedBox(height: 18),
                        const NeuSectionLabel('Notes & interview details'),
                        NeuInput(
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
                    NeuButton(
                      onPressed: () async {
                        await ref
                            .read(storeProvider)
                            .deleteApplication(_existing!.id);
                        if (context.mounted) context.pop();
                      },
                      child: Text('Delete manual entry',
                          style: TextStyle(color: palette.textSecondary)),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: palette.base,
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 14,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: NeuButton(
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
    final palette = NeuPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: palette.base,
          borderRadius: BorderRadius.circular(16),
          boxShadow: palette.inset(blur: 8, distance: 3),
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
                    .copyWith(color: palette.accent)),
          ],
        ),
      ),
    );
  }
}
