import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release metadata is not the Flutter template default', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final strings =
        File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final colors =
        File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final launchBackground =
        File('android/app/src/main/res/drawable/launch_background.xml')
            .readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/sakinaai/app/MainActivity.kt',
    ).readAsStringSync();

    expect(buildGradle, contains('namespace = "com.sakinaai.app"'));
    expect(buildGradle, contains('applicationId = "com.sakinaai.app"'));
    expect(buildGradle, contains('signingConfigs'));
    expect(buildGradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(buildGradle, isNot(contains('com.example')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(strings, contains('<string name="app_name">SakinaAI</string>'));
    expect(colors, contains('<color name="splash_background">#0F4A40</color>'));
    expect(launchBackground, contains('@mipmap/launch_image'));
    expect(activity, contains('package com.sakinaai.app'));
    expect(File('android/key.properties.example').existsSync(), isTrue);
    expect(
      File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png')
          .lengthSync(),
      greaterThan(2000),
    );
  });

  test('iOS release metadata is not the Flutter template default', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final launchStoryboard =
        File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
            .readAsStringSync();

    expect(plist, contains('<string>SakinaAI</string>'));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.sakinaai.app;'));
    expect(project, isNot(contains('com.example')));
    expect(launchStoryboard, contains('0.0588235294'));
    expect(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ).lengthSync(),
      greaterThan(20000),
    );
  });
}
