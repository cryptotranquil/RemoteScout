import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
