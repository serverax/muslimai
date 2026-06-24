class StagingClientConfig {
  static const String environment = 'staging';
  static const String apiBaseUrl = String.fromEnvironment(
    'SAKINA_API_BASE_URL',
    defaultValue: 'https://api.sakina-mobile-staging.example',
  );
}
