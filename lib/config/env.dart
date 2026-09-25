/// Build-time configuration (Phase 3).
///
/// Pass real values at run/build time — never hardcode secrets in source:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// The anon key is safe to ship in a client binary (it is guarded by RLS);
/// the service-role key must never leave the backend.
///
/// When these are left empty the app runs in Phase 1–2 mode: local Hive
/// persistence with the bundled mock listings.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// True when a live Supabase backend is configured for this build.
  static bool get isLiveConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
