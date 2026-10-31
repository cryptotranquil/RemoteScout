import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';

/// Small formatting helpers shared across screens.
String formatDayHeader(DateTime date) => DateFormat('EEE, d MMM').format(date);

String formatShortDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

String formatTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final t = TimeOfDay(hour: hour, minute: minute);
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $period';
}

/// "today", "yesterday", "2 days ago", "3 weeks ago", "over a month ago".
String formatPostedAgo(DateTime publishedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final days = reference.difference(publishedAt).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) {
    final weeks = (days / 7).floor();
    return '$weeks weeks ago';
  }
  return 'over a month ago';
}

/// Compact stamp for cards: "3h ago", "1d ago", "2w ago".
String formatShortAgo(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final delta = reference.difference(time);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  if (delta.inDays < 30) return '${(delta.inDays / 7).floor()}w ago';
  return '${(delta.inDays / 30).floor()}mo ago';
}

/// Header sync stamp — "Sync: just now" / "Sync: 12m ago" / "Sync: not yet".
String formatSyncStamp(DateTime? lastSync, {DateTime? now}) {
  if (lastSync == null) return 'Sync: not yet';
  final reference = now ?? DateTime.now();
  if (reference.difference(lastSync).inMinutes < 1) return 'Sync: just now';
  return 'Sync: ${formatShortAgo(lastSync, now: reference)}';
}

/// Full salary line for detail-oriented surfaces: "$28,000 – $38,000 USD".
String formatSalaryFull(Job job) {
  if (!job.hasSalary) return 'Salary not listed';
  final currency = job.currency ?? 'USD';
  final number = NumberFormat.decimalPattern('en_US');
  final min = job.salaryMin;
  final max = job.salaryMax;
  if (min != null && max != null) {
    return '\$${number.format(min.round())} – \$${number.format(max.round())} $currency';
  }
  return '\$${number.format((min ?? max!).round())} $currency';
}

/// Fit label paired with the score pill, e.g. "94% Match • High Fit".
String formatFitLabel(int score) {
  if (score >= 90) return 'High Fit';
  if (score >= 80) return 'Strong Fit';
  if (score >= 70) return 'Good Fit';
  if (score >= 50) return 'Partial Fit';
  return 'Low Fit';
}

/// Days until a listing closes; null when no expiry is known.
int? daysUntilExpiry(Job job, {DateTime? now}) {
  final expires = job.expiresAt;
  if (expires == null) return null;
  return expires.difference(now ?? DateTime.now()).inDays;
}
