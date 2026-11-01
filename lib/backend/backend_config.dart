/// Build-time address of the existing Supabase project.
///
/// Supply both values with `--dart-define-from-file=config/supabase.dev.json`.
/// Leave them empty to keep the on-phone campus store. Never pass a secret
/// or service-role key into the app.
class BackendConfig {
  const BackendConfig({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      publishableKey.length >= 20;

  factory BackendConfig.fromEnvironment() {
    const publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacy = String.fromEnvironment('SUPABASE_ANON_KEY');
    return BackendConfig(
      url: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: publishable.isNotEmpty ? publishable : legacy,
    );
  }
}
