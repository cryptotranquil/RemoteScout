/// Immutable domain models for RemoteScout (Phase 1–2 local scope).
///
/// Field names mirror 05_Backend_Schema.md so the Supabase mapping in
/// Phase 3 is a straight translation.
library;

enum LocationScope {
  worldwide,
  regionRestricted,
  countryRestricted;

  String get wire => switch (this) {
        LocationScope.worldwide => 'worldwide',
        LocationScope.regionRestricted => 'region_restricted',
        LocationScope.countryRestricted => 'country_restricted',
      };

  static LocationScope fromWire(String? value) => switch (value) {
        'worldwide' => LocationScope.worldwide,
        'region_restricted' => LocationScope.regionRestricted,
        'country_restricted' => LocationScope.countryRestricted,
        _ => LocationScope.regionRestricted,
      };
}

enum ApplicationStatus {
  neu('new', 'New'),
  saved('saved', 'Saved'),
  planToApply('plan_to_apply', 'Plan to apply'),
  applied('applied', 'Applied'),
  interview('interview', 'Interview'),
  rejected('rejected', 'Rejected'),
  offer('offer', 'Offer'),
  closed('closed', 'Closed');

  const ApplicationStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ApplicationStatus fromWire(String? value) =>
      ApplicationStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ApplicationStatus.neu,
      );
}

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.skills,
    required this.targetRoles,
    this.minimumSalary,
    required this.preferredCountries,
    this.preferredTimezones = const [],
    required this.experienceLevel,
    this.cvUrl,
    this.portfolioUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final List<String> skills;
  final List<String> targetRoles;
  final double? minimumSalary;
  final List<String> preferredCountries;
  final List<String> preferredTimezones;
  final String experienceLevel; // 'junior' | 'entry' | 'associate'
  final String? cvUrl;
  final String? portfolioUrl;
  final DateTime createdAt;

  Profile copyWith({
    String? name,
    String? email,
    List<String>? skills,
    List<String>? targetRoles,
    double? minimumSalary,
    List<String>? preferredCountries,
    List<String>? preferredTimezones,
    String? experienceLevel,
    String? cvUrl,
    String? portfolioUrl,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        skills: skills ?? this.skills,
        targetRoles: targetRoles ?? this.targetRoles,
        minimumSalary: minimumSalary ?? this.minimumSalary,
        preferredCountries: preferredCountries ?? this.preferredCountries,
        preferredTimezones: preferredTimezones ?? this.preferredTimezones,
        experienceLevel: experienceLevel ?? this.experienceLevel,
        cvUrl: cvUrl ?? this.cvUrl,
        portfolioUrl: portfolioUrl ?? this.portfolioUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'skills': skills,
        'target_roles': targetRoles,
        'minimum_salary': minimumSalary,
        'preferred_countries': preferredCountries,
        'preferred_timezones': preferredTimezones,
        'experience_level': experienceLevel,
        'cv_url': cvUrl,
        'portfolio_url': portfolioUrl,
        'created_at': createdAt.toIso8601String(),
      };

  static Profile fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        skills: _strings(json['skills']),
        targetRoles: _strings(json['target_roles']),
        minimumSalary: (json['minimum_salary'] as num?)?.toDouble(),
        preferredCountries: _strings(json['preferred_countries']),
        preferredTimezones: _strings(json['preferred_timezones']),
        experienceLevel: json['experience_level'] as String? ?? 'junior',
        cvUrl: json['cv_url'] as String?,
        portfolioUrl: json['portfolio_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Job {
  const Job({
    required this.id,
    required this.externalId,
    required this.source,
    required this.title,
    required this.company,
    required this.description,
    required this.applyUrl,
    required this.sourceUrl,
    required this.locationText,
    required this.locationScope,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    required this.employmentType,
    required this.publishedAt,
    required this.collectedAt,
    this.expiresAt,
    this.isExpiredReported = false,
  });

  final String id;
  final String externalId;
  final String source; // 'remotive' | 'remoteok' | 'manual'
  final String title;
  final String company;
  final String description;
  final String applyUrl;
  final String sourceUrl;
  final String locationText;
  final LocationScope locationScope;
  final double? salaryMin;
  final double? salaryMax;
  final String? currency;
  final String employmentType;
  final DateTime publishedAt;
  final DateTime collectedAt;
  final DateTime? expiresAt;
  final bool isExpiredReported;

  bool get hasSalary => salaryMin != null || salaryMax != null;

  String get salaryLabel {
    if (!hasSalary) return 'Salary not listed';
    final cur = currency ?? 'USD';
    String fmt(double v) {
      if (v >= 1000) {
        final k = v / 1000;
        return k == k.roundToDouble()
            ? '${k.round()}k'
            : k.toStringAsFixed(1);
      }
      return v.round().toString();
    }

    if (salaryMin != null && salaryMax != null) {
      return '$cur ${fmt(salaryMin!)}–${fmt(salaryMax!)}';
    }
    return '$cur ${fmt(salaryMin ?? salaryMax!)}';
  }

  String get employmentLabel => switch (employmentType) {
        'full_time' => 'Full-time',
        'part_time' => 'Part-time',
        'contract' => 'Contract',
        'freelance' => 'Freelance',
        'internship' => 'Internship',
        _ => employmentType,
      };

  /// Deterministic ingestion key — unique per (source, external_id).
  String get ingestKey => '$source|$externalId';

  /// Cross-source duplicate key — (company, title, apply_url) normalized.
  String get crossSourceKey {
    final companyN = company.toLowerCase().trim();
    final titleN = title.toLowerCase().trim();
    final urlN = applyUrl.toLowerCase().replaceAll(RegExp(r'/+$'), '').trim();
    return '$companyN|$titleN|$urlN';
  }

  Job copyWith({bool? isExpiredReported}) => Job(
        id: id,
        externalId: externalId,
        source: source,
        title: title,
        company: company,
        description: description,
        applyUrl: applyUrl,
        sourceUrl: sourceUrl,
        locationText: locationText,
        locationScope: locationScope,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        currency: currency,
        employmentType: employmentType,
        publishedAt: publishedAt,
        collectedAt: collectedAt,
        expiresAt: expiresAt,
        isExpiredReported: isExpiredReported ?? this.isExpiredReported,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'external_id': externalId,
        'source': source,
        'title': title,
        'company': company,
        'description': description,
        'apply_url': applyUrl,
        'source_url': sourceUrl,
        'location_text': locationText,
        'location_scope': locationScope.wire,
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'currency': currency,
        'employment_type': employmentType,
        'published_at': publishedAt.toIso8601String(),
        'collected_at': collectedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'is_expired_reported': isExpiredReported,
      };

  static Job fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        externalId: json['external_id'] as String,
        source: json['source'] as String,
        title: json['title'] as String,
        company: json['company'] as String,
        description: json['description'] as String? ?? '',
        applyUrl: json['apply_url'] as String,
        sourceUrl: json['source_url'] as String,
        locationText: json['location_text'] as String? ?? 'Unspecified',
        locationScope: LocationScope.fromWire(json['location_scope'] as String?),
        salaryMin: (json['salary_min'] as num?)?.toDouble(),
        salaryMax: (json['salary_max'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        employmentType: json['employment_type'] as String? ?? 'full_time',
        publishedAt: DateTime.parse(json['published_at'] as String),
        collectedAt: DateTime.parse(json['collected_at'] as String),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String),
        isExpiredReported: json['is_expired_reported'] as bool? ?? false,
      );
}

class JobMatch {
  const JobMatch({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchReason,
    required this.breakdown,
    this.isSeen = false,
    this.isSaved = false,
    this.isRejected = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String jobId;
  final int matchScore; // 0–100
  final List<String> matchedSkills;
  final List<String> missingSkills;

  /// Human-readable summary, e.g.
  /// "Matches SQL and Excel · Worldwide eligible · Posted 2 days ago".
  final String matchReason;

  /// "Why this matched" checklist lines (expanded in Job Details).
  final List<String> breakdown;
  final bool isSeen;
  final bool isSaved;
  final bool isRejected;
  final DateTime createdAt;

  JobMatch copyWith({
    int? matchScore,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    String? matchReason,
    List<String>? breakdown,
    bool? isSeen,
    bool? isSaved,
    bool? isRejected,
  }) =>
      JobMatch(
        id: id,
        userId: userId,
        jobId: jobId,
        matchScore: matchScore ?? this.matchScore,
        matchedSkills: matchedSkills ?? this.matchedSkills,
        missingSkills: missingSkills ?? this.missingSkills,
        matchReason: matchReason ?? this.matchReason,
        breakdown: breakdown ?? this.breakdown,
        isSeen: isSeen ?? this.isSeen,
        isSaved: isSaved ?? this.isSaved,
        isRejected: isRejected ?? this.isRejected,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'job_id': jobId,
        'match_score': matchScore,
        'matched_skills': matchedSkills,
        'missing_skills': missingSkills,
        'match_reason': matchReason,
        'breakdown': breakdown,
        'is_seen': isSeen,
        'is_saved': isSaved,
        'is_rejected': isRejected,
        'created_at': createdAt.toIso8601String(),
      };

  static JobMatch fromJson(Map<String, dynamic> json) => JobMatch(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        jobId: json['job_id'] as String,
        matchScore: (json['match_score'] as num).toInt(),
        matchedSkills: _strings(json['matched_skills']),
        missingSkills: _strings(json['missing_skills']),
        matchReason: json['match_reason'] as String? ?? '',
        breakdown: _strings(json['breakdown']),
        isSeen: json['is_seen'] as bool? ?? false,
        isSaved: json['is_saved'] as bool? ?? false,
        isRejected: json['is_rejected'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Application {
  const Application({
    required this.id,
    required this.userId,
    this.jobId,
    required this.status,
    this.appliedAt,
    this.followUpAt,
    this.cvVersion,
    this.coverLetter,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// Null only for "Add manually" entries (which create a `manual` Job row
  /// first in the local store — kept nullable to mirror the backend schema).
  final String? jobId;
  final ApplicationStatus status;
  final DateTime? appliedAt;
  final DateTime? followUpAt;
  final String? cvVersion;
  final String? coverLetter;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Application copyWith({
    String? jobId,
    ApplicationStatus? status,
    DateTime? appliedAt,
    DateTime? followUpAt,
    String? cvVersion,
    String? coverLetter,
    String? notes,
    DateTime? updatedAt,
  }) =>
      Application(
        id: id,
        userId: userId,
        jobId: jobId ?? this.jobId,
        status: status ?? this.status,
        appliedAt: appliedAt ?? this.appliedAt,
        followUpAt: followUpAt ?? this.followUpAt,
        cvVersion: cvVersion ?? this.cvVersion,
        coverLetter: coverLetter ?? this.coverLetter,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'job_id': jobId,
        'status': status.wire,
        'applied_at': appliedAt?.toIso8601String(),
        'follow_up_at': followUpAt?.toIso8601String(),
        'cv_version': cvVersion,
        'cover_letter': coverLetter,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Application fromJson(Map<String, dynamic> json) => Application(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        jobId: json['job_id'] as String?,
        status: ApplicationStatus.fromWire(json['status'] as String?),
        appliedAt: json['applied_at'] == null
            ? null
            : DateTime.parse(json['applied_at'] as String),
        followUpAt: json['follow_up_at'] == null
            ? null
            : DateTime.parse(json['follow_up_at'] as String),
        cvVersion: json['cv_version'] as String?,
        coverLetter: json['cover_letter'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class NotificationPrefs {
  const NotificationPrefs({
    this.digestTime = '08:00',
    this.minMatchScore = 70,
    this.maxJobsPerDay = 5,
    this.weekendEnabled = false,
  });

  /// HH:mm local time for the daily digest.
  final String digestTime;
  final int minMatchScore;
  final int maxJobsPerDay;
  final bool weekendEnabled;

  NotificationPrefs copyWith({
    String? digestTime,
    int? minMatchScore,
    int? maxJobsPerDay,
    bool? weekendEnabled,
  }) =>
      NotificationPrefs(
        digestTime: digestTime ?? this.digestTime,
        minMatchScore: minMatchScore ?? this.minMatchScore,
        maxJobsPerDay: maxJobsPerDay ?? this.maxJobsPerDay,
        weekendEnabled: weekendEnabled ?? this.weekendEnabled,
      );

  Map<String, dynamic> toJson() => {
        'digest_time': digestTime,
        'min_match_score': minMatchScore,
        'max_jobs_per_day': maxJobsPerDay,
        'weekend_enabled': weekendEnabled,
      };

  static NotificationPrefs fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        digestTime: json['digest_time'] as String? ?? '08:00',
        minMatchScore: (json['min_match_score'] as num?)?.toInt() ?? 70,
        maxJobsPerDay: (json['max_jobs_per_day'] as num?)?.toInt() ?? 5,
        weekendEnabled: json['weekend_enabled'] as bool? ?? false,
      );
}

List<String> _strings(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];
