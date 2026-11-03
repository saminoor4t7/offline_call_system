#!/usr/bin/env bash
# Run once, from the folder that contains this file:  bash setup.sh
set -e
if ! command -v flutter >/dev/null; then echo "Flutter SDK not found in PATH"; exit 1; fi

# 1) Generate the native Android project around our lib/ code.
flutter create --platforms=android --org com.aircall --project-name aircall . >/dev/null

# 2) Our manifest (permissions) replaces the generated one.
cp android_overlay/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

# 3) Raise minSdk to 23 (required by WebRTC), preserving each Gradle DSL.
if [ -f android/app/build.gradle ]; then
  sed -i -E 's/minSdkVersion +flutter\.minSdkVersion/minSdkVersion 23/' android/app/build.gradle
  echo "patched android/app/build.gradle"
fi
if [ -f android/app/build.gradle.kts ]; then
  sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
  echo "patched android/app/build.gradle.kts"
fi

# Flutter may create its sample counter test for a new project. Remove only
# that generated sample; never delete a user's test suite.
if [ -f test/widget_test.dart ] && grep -q 'Counter increments smoke test' test/widget_test.dart; then
  rm test/widget_test.dart
  rmdir test 2>/dev/null || true
fi

flutter pub get
dart run flutter_launcher_icons
echo
echo "Done. Connect an Android phone or start an emulator, then run:"
echo "  flutter devices"
echo "  flutter run -d <android-device-id> --release"
