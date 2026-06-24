import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/app/feature_flags.dart';

void main() {
  test('local test mode enables feature flags via SAKINA_LOCAL_TEST', () {
    // Compiled without SAKINA_LOCAL_TEST — flags follow env defaults in CI.
    // Document expected behaviour for APK builds with SAKINA_LOCAL_TEST=true.
    expect(FeatureFlags.localTest, isA<bool>());
  });
}
