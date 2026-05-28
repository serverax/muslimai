class FeatureFlags {
  const FeatureFlags._();

  static const bool quran =
      bool.fromEnvironment('SAKINA_FEATURE_QURAN', defaultValue: false);
  static const bool prayer =
      bool.fromEnvironment('SAKINA_FEATURE_PRAYER', defaultValue: false);
  static const bool community =
      bool.fromEnvironment('SAKINA_FEATURE_COMMUNITY', defaultValue: false);
  static const bool knowledge =
      bool.fromEnvironment('SAKINA_FEATURE_KNOWLEDGE', defaultValue: false);
}
