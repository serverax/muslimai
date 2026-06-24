/// Mobile app feature flag from GET /v1/features.
class AppFeature {
  const AppFeature({
    required this.featureKey,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.category,
    required this.iconKey,
    required this.enabled,
    required this.requiresLogin,
    required this.requiresPremium,
    required this.adminOnly,
    required this.scholarOnly,
    required this.comingSoon,
    required this.maintenanceMode,
    required this.displayOrder,
    this.userHasPremium = false,
    this.userLoggedIn = false,
  });

  final String featureKey;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final String category;
  final String iconKey;
  final bool enabled;
  final bool requiresLogin;
  final bool requiresPremium;
  final bool adminOnly;
  final bool scholarOnly;
  final bool comingSoon;
  final bool maintenanceMode;
  final int displayOrder;
  final bool userHasPremium;
  final bool userLoggedIn;

  String title(bool isArabic) => isArabic ? titleAr : titleEn;
  String description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  factory AppFeature.fromJson(Map<String, dynamic> json) {
    return AppFeature(
      featureKey: json['feature_key']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleAr: json['title_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString() ?? '',
      descriptionAr: json['description_ar']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      iconKey: json['icon_key']?.toString() ?? 'apps',
      enabled: json['enabled'] == true,
      requiresLogin: json['requires_login'] == true,
      requiresPremium: json['requires_premium'] == true,
      adminOnly: json['admin_only'] == true,
      scholarOnly: json['scholar_only'] == true,
      comingSoon: json['coming_soon'] == true,
      maintenanceMode: json['maintenance_mode'] == true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      userHasPremium: json['user_has_premium'] == true,
      userLoggedIn: json['user_logged_in'] == true,
    );
  }

  /// Local-test fallback when API unavailable.
  static List<AppFeature> localDefaults() => [
        const AppFeature(
          featureKey: 'ask_ai_shaikh',
          titleEn: 'Ask AI Shaikh',
          titleAr: 'اسأل الشيخ الذكي',
          descriptionEn: '',
          descriptionAr: '',
          category: 'guidance',
          iconKey: 'chat',
          enabled: true,
          requiresLogin: true,
          requiresPremium: false,
          adminOnly: false,
          scholarOnly: false,
          comingSoon: false,
          maintenanceMode: false,
          displayOrder: 1,
        ),
        const AppFeature(
          featureKey: 'quran_reader',
          titleEn: 'Quran Reader',
          titleAr: 'قارئ القرآن',
          descriptionEn: '',
          descriptionAr: '',
          category: 'study',
          iconKey: 'menu_book',
          enabled: true,
          requiresLogin: false,
          requiresPremium: false,
          adminOnly: false,
          scholarOnly: false,
          comingSoon: false,
          maintenanceMode: false,
          displayOrder: 2,
        ),
        const AppFeature(
          featureKey: 'tafsir',
          titleEn: 'Tafsir',
          titleAr: 'تفسير',
          descriptionEn: '',
          descriptionAr: '',
          category: 'study',
          iconKey: 'auto_stories',
          enabled: true,
          requiresLogin: false,
          requiresPremium: true,
          adminOnly: false,
          scholarOnly: false,
          comingSoon: false,
          maintenanceMode: false,
          displayOrder: 4,
        ),
        const AppFeature(
          featureKey: 'masjid_near_me',
          titleEn: 'Masjid Near Me',
          titleAr: 'مسجد قريب',
          descriptionEn: '',
          descriptionAr: '',
          category: 'community',
          iconKey: 'mosque',
          enabled: true,
          requiresLogin: false,
          requiresPremium: false,
          adminOnly: false,
          scholarOnly: false,
          comingSoon: true,
          maintenanceMode: false,
          displayOrder: 14,
        ),
      ];
}

enum FeatureAccess { allowed, loginRequired, premiumLocked, comingSoon, disabled, maintenance, accessDenied }

extension AppFeatureAccess on AppFeature {
  FeatureAccess accessFor({
    required bool loggedIn,
    required bool hasPremium,
    required bool isAdmin,
    required bool isScholar,
  }) {
    if (adminOnly && !isAdmin) return FeatureAccess.accessDenied;
    if (scholarOnly && !isScholar && !isAdmin) return FeatureAccess.accessDenied;
    if (maintenanceMode) return FeatureAccess.maintenance;
    if (comingSoon) return FeatureAccess.comingSoon;
    if (!enabled) return FeatureAccess.disabled;
    if (requiresLogin && !loggedIn) return FeatureAccess.loginRequired;
    if (requiresPremium && !hasPremium && !isAdmin) return FeatureAccess.premiumLocked;
    return FeatureAccess.allowed;
  }
}
