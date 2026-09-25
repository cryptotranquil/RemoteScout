/// Rule-based match scorer (TRD §6, PRD §6.3).
///
///   score = skill (0–40) + title (0–25) + location (0–20)
///         + experience (0–10) + freshness (0–5)
///
/// Every score is paired with a human-readable reason — the scoring logic
/// must never be a black box to the user. The same algorithm is mirrored
/// server-side in `backend/functions/_shared/scoring.ts`.
library;

import '../../models/models.dart';

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.skill,
    required this.title,
    required this.location,
    required this.experience,
    required this.freshness,
  });

  final int skill; // 0–40
  final int title; // 0–25
  final int location; // 0–20
  final int experience; // 0–10
  final int freshness; // 0–5

  int get total => skill + title + location + experience + freshness;
}

class MatchResult {
  const MatchResult({
    required this.score,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchReason,
    required this.breakdown,
    required this.reasons,
  });

  final int score;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String matchReason;
  final ScoreBreakdown breakdown;
  final List<String> reasons;
}

/// Known skill vocabulary with the aliases used for keyword extraction.
const Map<String, List<String>> kSkillAliases = {
  'SQL': ['sql', 'postgres', 'postgresql', 'mysql', 'bigquery', 't-sql', 'tsql'],
  'Excel': ['excel', 'vlookup', 'pivot table', 'pivot tables', 'spreadsheets'],
  'Google Sheets': ['google sheets', 'gsheets'],
  'Tableau': ['tableau'],
  'Power BI': ['power bi', 'powerbi', 'dax'],
  'Looker': ['looker', 'looker studio', 'lookml'],
  'Python': ['python', 'pandas', 'numpy'],
  'R': ['tidyverse', 'ggplot', 'shiny', 'r language'],
  'Statistics': [
    'statistics',
    'statistical',
    'hypothesis testing',
    'regression',
    'a/b testing',
  ],
  'Data Cleaning': [
    'data cleaning',
    'data wrangling',
    'data quality',
    'data entry',
    'etl',
  ],
  'Data Visualization': [
    'data visualization',
    'data visualisation',
    'dashboards',
    'dashboarding',
    'charting',
  ],
  'Reporting': ['reporting', 'weekly reports', 'monthly reports', 'kpi reports'],
  'Communication': ['stakeholder', 'cross-functional', 'communication skills'],
};

const Set<String> kJuniorKeywords = {
  'junior',
  'jr',
  'entry',
  'entry-level',
  'entry level',
  'intern',
  'internship',
  'graduate',
  'graduation',
  'trainee',
  'associate',
  'assistant',
  'new grad',
  '0-2 years',
  '0 to 2 years',
  '1+ year',
  '1 year of',
};

const Set<String> kSeniorKeywords = {
  'senior',
  'sr',
  'lead',
  'principal',
  'staff',
  'head of',
  '5+ years',
  '5+ year',
  '7+ years',
  '10+ years',
};

const Set<String> kMidKeywords = {
  'mid-level',
  'mid level',
  '2+ years',
  '2+ year',
  '3+ years',
  '3 years of',
  'experienced analyst',
};

const Set<String> kTitleStopwords = {
  'a', 'an', 'the', 'of', 'for', 'and', 'to', 'at', 'in', 'on', 'with',
  'remote', 'wfh', 'position', 'role', 'i', 'ii', 'iii',
};

/// Canonicalizes free-text user skills (e.g. "powerbi" → "Power BI").
String canonicalSkill(String input) {
  final lower = input.toLowerCase().trim();
  for (final entry in kSkillAliases.entries) {
    if (entry.key.toLowerCase() == lower) return entry.key;
    if (entry.value.contains(lower)) return entry.key;
  }
  return input.trim();
}

Set<String> canonicalSkills(Iterable<String> inputs) =>
    inputs.map(canonicalSkill).toSet();

/// Keyword-extracts the skills a job talks about from title + description.
Set<String> detectJobSkills(Job job) {
  final text = '${job.title} ${job.description}'.toLowerCase();
  final found = <String>{};
  for (final entry in kSkillAliases.entries) {
    for (final alias in entry.value) {
      if (_containsPhrase(text, alias)) {
        found.add(entry.key);
        break;
      }
    }
  }
  // Bare "R" is only trusted with word boundaries to avoid false hits.
  if (!found.contains('R') && RegExp(r'(?<![a-z])r(?![a-z])').hasMatch(text)) {
    if (text.contains('statistic') || text.contains('analysis') || text.contains('tidy')) {
      found.add('R');
    }
  }
  return found;
}

bool _containsPhrase(String text, String phrase) {
  if (phrase.length <= 3 || !phrase.contains(' ')) {
    final escaped = RegExp.escape(phrase);
    return RegExp('(?<![a-z])$escaped(?![a-z])').hasMatch(text);
  }
  return text.contains(phrase);
}

int _skillScore(Set<String> required, Set<String> matched) {
  if (required.isEmpty) return 20; // neutral when the listing names no tools
  return (40 * matched.length / required.length).round();
}

int _titleScore(String title, List<String> targetRoles) {
  if (targetRoles.isEmpty) return 0;
  final titleTokens = _titleTokens(title);
  double best = 0;
  for (final role in targetRoles) {
    final roleTokens = _titleTokens(role);
    if (roleTokens.isEmpty || titleTokens.isEmpty) continue;
    final intersection = titleTokens.intersection(roleTokens).length;
    final union = titleTokens.union(roleTokens).length;
    double sim = union == 0 ? 0 : intersection / union;
    final rolePhrase = role.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').trim();
    final titleLower = title.toLowerCase();
    if (rolePhrase.length > 4 &&
        (titleLower.contains(rolePhrase) ||
            rolePhrase.contains(titleLower.trim()))) {
      sim = sim < 0.85 ? 0.85 : sim;
    }
    if (sim > best) best = sim;
  }
  return (25 * best).round().clamp(0, 25);
}

Set<String> _titleTokens(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty && !kTitleStopwords.contains(t))
    .toSet();

int _locationScore(Job job, Profile profile) {
  switch (job.locationScope) {
    case LocationScope.worldwide:
      return 20;
    case LocationScope.regionRestricted:
      return 6;
    case LocationScope.countryRestricted:
      final text = job.locationText.toLowerCase();
      for (final country in profile.preferredCountries) {
        if (country.toLowerCase() == 'worldwide') continue;
        if (text.contains(country.toLowerCase())) return 12;
      }
      return 2;
  }
}

int _experienceScore(Job job) {
  final text = '${job.title} ${job.description}'.toLowerCase();
  bool mentions(Set<String> words) => words.any(text.contains);
  if (mentions(kSeniorKeywords) && !mentions(kJuniorKeywords)) return 0;
  if (mentions(kJuniorKeywords)) return 10;
  if (mentions(kMidKeywords)) return 4;
  return 6;
}

int _freshnessScore(DateTime publishedAt, DateTime now) {
  final days = now.difference(publishedAt).inDays;
  if (days <= 1) return 5;
  if (days <= 3) return 4;
  if (days <= 7) return 3;
  if (days <= 14) return 2;
  if (days <= 30) return 1;
  return 0;
}

String _freshnessPhrase(DateTime publishedAt, DateTime now) {
  final days = now.difference(publishedAt).inDays;
  if (days <= 0) return 'Posted today';
  if (days == 1) return 'Posted yesterday';
  if (days < 30) return 'Posted $days days ago';
  return 'Posted over a month ago';
}

String _locationPhrase(Job job) => switch (job.locationScope) {
      LocationScope.worldwide => 'Worldwide eligible',
      LocationScope.regionRestricted => 'Region-restricted',
      LocationScope.countryRestricted => 'Country-restricted',
    };

String _joinAnd(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

/// Runs the full transparent matcher for [job] against [profile].
MatchResult scoreJob({
  required Job job,
  required Profile profile,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();

  final userSkills = canonicalSkills(profile.skills);
  final required = detectJobSkills(job);
  final matched = required.intersection(userSkills).toList()..sort();
  final missing = required.difference(userSkills).toList()..sort();

  final skill = _skillScore(required, matched.toSet());
  final title = _titleScore(job.title, profile.targetRoles);
  final location = _locationScore(job, profile);
  final experience = _experienceScore(job);
  final freshness = _freshnessScore(job.publishedAt, reference);

  final breakdown = ScoreBreakdown(
    skill: skill,
    title: title,
    location: location,
    experience: experience,
    freshness: freshness,
  );

  // Human-readable summary clauses (joined with ' · ').
  final clauses = <String>[
    if (matched.isNotEmpty) 'Matches ${_joinAnd(matched)}',
    if (experience == 10) 'Junior-friendly',
    _locationPhrase(job),
    _freshnessPhrase(job.publishedAt, reference),
  ];

  // "Why this matched" checklist.
  final reasons = <String>[
    if (matched.isNotEmpty) '✓ Matches ${matched.join(', ')}',
    if (matched.isEmpty && required.isNotEmpty) '— None of your listed skills called out',
    if (required.isEmpty) '— Listing does not name specific tools',
    if (experience == 10)
      '✓ Junior-friendly'
    else if (experience == 0)
      '— Reads as senior-level'
    else
      '— Experience level unclear',
    if (location == 20)
      '✓ Worldwide eligible'
    else
      '— ${_locationPhrase(job)} (${job.locationText})',
    '✓ ${_freshnessPhrase(job.publishedAt, reference)}',
  ];

  return MatchResult(
    score: breakdown.total.clamp(0, 100),
    matchedSkills: matched,
    missingSkills: missing,
    matchReason: clauses.join(' · '),
    breakdown: breakdown,
    reasons: reasons,
  );
}
