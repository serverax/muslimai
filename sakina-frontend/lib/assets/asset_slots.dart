import 'package:flutter/widgets.dart';

enum SakinaAssetSlotType {
  brand,
  tabHero,
  onboarding,
  storeListing,
}

enum SakinaAssetSlotId {
  appIcon,
  brandMark,
  homeHero,
  tutoringHero,
  quranHero,
  prayerHero,
  parentHero,
  onboardingPrivacy,
  onboardingAuthenticity,
  playStoreFeatureGraphic,
  appStorePreview,
}

@immutable
class SakinaAssetSlot {
  const SakinaAssetSlot({
    required this.id,
    required this.type,
    required this.label,
    required this.aspectRatio,
    required this.minWidth,
    required this.minHeight,
  });

  final SakinaAssetSlotId id;
  final SakinaAssetSlotType type;
  final String label;
  final double aspectRatio;
  final int minWidth;
  final int minHeight;

  String get key => id.name;
}

abstract final class SakinaAssetSlots {
  static const all = <SakinaAssetSlot>[
    SakinaAssetSlot(
      id: SakinaAssetSlotId.appIcon,
      type: SakinaAssetSlotType.brand,
      label: 'App icon',
      aspectRatio: 1,
      minWidth: 1024,
      minHeight: 1024,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.brandMark,
      type: SakinaAssetSlotType.brand,
      label: 'Brand mark',
      aspectRatio: 1,
      minWidth: 512,
      minHeight: 512,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.homeHero,
      type: SakinaAssetSlotType.tabHero,
      label: 'Home hero',
      aspectRatio: 16 / 9,
      minWidth: 1600,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.tutoringHero,
      type: SakinaAssetSlotType.tabHero,
      label: 'Tutoring hero',
      aspectRatio: 16 / 9,
      minWidth: 1600,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.quranHero,
      type: SakinaAssetSlotType.tabHero,
      label: 'Quran hero',
      aspectRatio: 16 / 9,
      minWidth: 1600,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.prayerHero,
      type: SakinaAssetSlotType.tabHero,
      label: 'Prayer hero',
      aspectRatio: 16 / 9,
      minWidth: 1600,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.parentHero,
      type: SakinaAssetSlotType.tabHero,
      label: 'Parent hero',
      aspectRatio: 16 / 9,
      minWidth: 1600,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.onboardingPrivacy,
      type: SakinaAssetSlotType.onboarding,
      label: 'Onboarding privacy',
      aspectRatio: 4 / 3,
      minWidth: 1200,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.onboardingAuthenticity,
      type: SakinaAssetSlotType.onboarding,
      label: 'Onboarding authenticity',
      aspectRatio: 4 / 3,
      minWidth: 1200,
      minHeight: 900,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.playStoreFeatureGraphic,
      type: SakinaAssetSlotType.storeListing,
      label: 'Google Play feature graphic',
      aspectRatio: 1024 / 500,
      minWidth: 1024,
      minHeight: 500,
    ),
    SakinaAssetSlot(
      id: SakinaAssetSlotId.appStorePreview,
      type: SakinaAssetSlotType.storeListing,
      label: 'App Store preview',
      aspectRatio: 1290 / 2796,
      minWidth: 1290,
      minHeight: 2796,
    ),
  ];

  static final byId = Map<SakinaAssetSlotId, SakinaAssetSlot>.unmodifiable({
    for (final slot in all) slot.id: slot,
  });

  static SakinaAssetSlot get(SakinaAssetSlotId id) => byId[id]!;
}
