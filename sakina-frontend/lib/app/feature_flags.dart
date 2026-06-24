class FeatureFlags {
  const FeatureFlags._();

  static const bool localTest =
      bool.fromEnvironment('SAKINA_LOCAL_TEST', defaultValue: false);

  static const bool quran =
      bool.fromEnvironment('SAKINA_FEATURE_QURAN', defaultValue: false) ||
      localTest;

  static const bool prayer =
      bool.fromEnvironment('SAKINA_FEATURE_PRAYER', defaultValue: false) ||
      localTest;

  static const bool community =
      bool.fromEnvironment('SAKINA_FEATURE_COMMUNITY', defaultValue: false) ||
      localTest;

  static const bool knowledge =
      bool.fromEnvironment('SAKINA_FEATURE_KNOWLEDGE', defaultValue: false) ||
      localTest;
}
