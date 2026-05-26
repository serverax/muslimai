import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release metadata is not the Flutter template default', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final strings =
        File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/sakinaai/app/MainActivity.kt',
    ).readAsStringSync();

    expect(buildGradle, contains('namespace = "com.sakinaai.app"'));
    expect(buildGradle, contains('applicationId = "com.sakinaai.app"'));
    expect(buildGradle, isNot(contains('com.example')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(strings, contains('<string name="app_name">SakinaAI</string>'));
    expect(activity, contains('package com.sakinaai.app'));
  });

  test('iOS release metadata is not the Flutter template default', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(plist, contains('<string>SakinaAI</string>'));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.sakinaai.app;'));
    expect(project, isNot(contains('com.example')));
  });
}
