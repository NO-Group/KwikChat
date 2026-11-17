/// Build-time configuration.
///
/// Values are injected with `--dart-define` so no secret ever lives in the repo:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// The anon key is public by design (it ships in every Supabase client);
/// security comes from Row Level Security in `supabase/migrations`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

  /// True when the build was given a backend to talk to.
  static bool get isConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.length > 20;
}
