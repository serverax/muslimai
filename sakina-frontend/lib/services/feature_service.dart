import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/feature_flags.dart';
import '../app/app_feature.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/workflow_states.dart';

/// Loads and caches feature flags from GET /v1/features.
class FeatureService extends ChangeNotifier {
  FeatureService._();
  static final FeatureService instance = FeatureService._();

  List<AppFeature> _features = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<AppFeature> get features => List.unmodifiable(_features);
  bool get loaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;

  AppFeature? byKey(String key) {
    try {
      return _features.firstWhere((f) => f.featureKey == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> load(ApiService api) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final json = await api.listFeatures();
      final list = json['features'];
      if (list is List) {
        _features = list
            .whereType<Map<String, dynamic>>()
            .map(AppFeature.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      }
      _loaded = true;
    } catch (e) {
      _error = e.toString();
      if (FeatureFlags.localTest) {
        _features = AppFeature.localDefaults();
        _loaded = true;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool hasPremium(AuthSession? session, Map<String, dynamic>? entitlements) {
    if (FeatureFlags.localTest) return true;
    if (entitlements == null) return false;
    final tier = entitlements['tier']?.toString() ?? 'free';
    if (tier != 'free') return true;
    final items = entitlements['entitlements'];
    if (items is List && items.isNotEmpty) return true;
    return false;
  }

  void navigateToFeature({
    required BuildContext context,
    required String featureKey,
    required AppState appState,
    AuthSession? session,
    Map<String, dynamic>? entitlements,
    required bool isAdmin,
    required bool isScholar,
    required Widget Function() onAllowed,
  }) {
    final feature = byKey(featureKey);
    final name = feature?.titleEn ?? featureKey;
    final loggedIn = session != null;
    final premium = hasPremium(session, entitlements);

    if (feature == null && FeatureFlags.localTest) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => onAllowed()));
      return;
    }
    if (feature == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GateStateScreen.notImplemented(featureName: name),
        ),
      );
      return;
    }

    final access = feature.accessFor(
      loggedIn: loggedIn,
      hasPremium: premium,
      isAdmin: isAdmin,
      isScholar: isScholar,
    );

    switch (access) {
      case FeatureAccess.allowed:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => onAllowed()));
      case FeatureAccess.loginRequired:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GateStateScreen.loginRequired(
              featureName: name,
              appState: appState,
              onLoggedIn: (_) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => onAllowed()));
              },
            ),
          ),
        );
      case FeatureAccess.premiumLocked:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GateStateScreen.premiumLocked(
              featureName: name,
              session: session,
            ),
          ),
        );
      case FeatureAccess.comingSoon:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GateStateScreen.comingSoon(featureName: name)),
        );
      case FeatureAccess.disabled:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GateStateScreen.disabled(featureName: name)),
        );
      case FeatureAccess.maintenance:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GateStateScreen.maintenance(featureName: name)),
        );
      case FeatureAccess.accessDenied:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GateStateScreen.accessDenied(featureName: name)),
        );
    }
  }
}
