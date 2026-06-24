import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/models/app_feature.dart';

void main() {
  test('login-required feature blocks guest', () {
    const f = AppFeature(
      featureKey: 'bookmarks',
      titleEn: 'Bookmarks',
      titleAr: '',
      descriptionEn: '',
      descriptionAr: '',
      category: 'personal',
      iconKey: 'bookmark',
      enabled: true,
      requiresLogin: true,
      requiresPremium: false,
      adminOnly: false,
      scholarOnly: false,
      comingSoon: false,
      maintenanceMode: false,
      displayOrder: 1,
    );
    expect(
      f.accessFor(loggedIn: false, hasPremium: false, isAdmin: false, isScholar: false),
      FeatureAccess.loginRequired,
    );
    expect(
      f.accessFor(loggedIn: true, hasPremium: false, isAdmin: false, isScholar: false),
      FeatureAccess.allowed,
    );
  });

  test('premium feature blocks free user', () {
    const f = AppFeature(
      featureKey: 'tafsir',
      titleEn: 'Tafsir',
      titleAr: '',
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
    );
    expect(
      f.accessFor(loggedIn: true, hasPremium: false, isAdmin: false, isScholar: false),
      FeatureAccess.premiumLocked,
    );
  });

  test('coming soon overrides enabled', () {
    const f = AppFeature(
      featureKey: 'masjid_near_me',
      titleEn: 'Masjid',
      titleAr: '',
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
    );
    expect(
      f.accessFor(loggedIn: true, hasPremium: true, isAdmin: false, isScholar: false),
      FeatureAccess.comingSoon,
    );
  });
}
