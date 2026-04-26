# Play Store Release Checklist

## Hard blockers before upload

1. Create a real Android package name.
   Current value: `com.example.lerolove`
   Files that must match:
   - `android/app/build.gradle.kts`
   - `android/app/src/main/kotlin/.../MainActivity.kt`
   - Firebase Android app registration

2. Regenerate Firebase Android config for the real package name.
   - Create/update the Android app in Firebase
   - Download a fresh `android/app/google-services.json`
   - Make sure the `package_name` inside it matches your final app id

3. Configure release signing.
   - Copy `android/key.properties.example` to `android/key.properties`
   - Create or place your upload keystore on disk
   - Fill in the real passwords and alias

4. Build a release bundle, not a debug APK.
   - `flutter build appbundle --release`

## Strongly recommended before upload

1. Replace placeholder versioning in `pubspec.yaml`
   - Example: `1.0.1+2`

2. Run:
   - `flutter analyze`
   - `flutter test` after adding at least smoke tests

3. Verify production backend and notifications
   - OTP send/verify
   - profile creation
   - photo upload
   - discovery
   - chat
   - push notifications

4. Verify localization manually
   - English
   - Chichewa
   - switch both directions on all tabs/screens

5. Verify store-facing assets
   - app icon
   - screenshots
   - privacy policy URL
   - support email
   - content rating

## Notes

- Release signing now automatically uses `android/key.properties` if present.
- If that file is missing, the project still falls back to debug signing so local release-style runs keep working.
- Production Android cleartext traffic is disabled in the main manifest. Debug/profile builds still allow it.
