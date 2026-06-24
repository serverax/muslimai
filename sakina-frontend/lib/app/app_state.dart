import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AppLanguage language,
    required bool onboardingComplete,
  })  : _language = language,
        _onboardingComplete = onboardingComplete;

  static const _languageKey = 'sakina_language';
  static const _onboardingKey = 'sakina_onboarding_complete';

  AppLanguage _language;
  bool _onboardingComplete;

  AppLanguage get language => _language;
  bool get isArabic => _language == AppLanguage.arabic;
  bool get onboardingComplete => _onboardingComplete;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    final onboarding = prefs.getBool(_onboardingKey) ?? false;
    final language =
        languageCode == 'ar' ? AppLanguage.arabic : AppLanguage.english;
    return AppState(
      language: language,
      onboardingComplete: onboarding,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _languageKey, language == AppLanguage.arabic ? 'ar' : 'en');
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }

  String t(String key) => AppStrings.text(key, _language);
}
