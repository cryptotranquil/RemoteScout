import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light / dark / system selection. Kept in memory (a display preference,
/// not part of the synced profile).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
