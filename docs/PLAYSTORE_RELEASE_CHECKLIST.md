# Play Store Release Checklist

## Hard blockers before upload

1. Create a real Android package name.
   Current value: `com.loversconnectmw.app`
   Files that must match:
   - `android/app/build.gradle.kts`
   - `android/app/src/main/kotlin/.../MainActivity.kt`
   - Firebase Android app registration

2. Regenerate Firebase Android config for the real package name.
   - Create/update the Android app in Firebase
   - Download a fresh `android/app/google-services.json`
   - Make sure the `package_name` inside it matches your final app id
   - Run `flutterfire configure` again so `lib/firebase_options.dart` is generated from the same Firebase app

3. Configure release signing.
   - Copy `android/key.properties.example` to `android/key.properties`
   - Create or place your upload keystore on disk
   - Fill in the real passwords and alias
   - Alternatively set `LEROLOVE_UPLOAD_STORE_FILE`, `LEROLOVE_UPLOAD_STORE_PASSWORD`, `LEROLOVE_UPLOAD_KEY_ALIAS`, and `LEROLOVE_UPLOAD_KEY_PASSWORD`

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
   - privacy policy URL from `docs/playstore-policy-site`
   - support email
   - content rating

## Notes

- Release signing now automatically uses `android/key.properties` if present.
- If signing values are missing, release APK/AAB tasks fail before packaging so you do not accidentally upload a debug-signed build.
- Production Android cleartext traffic is disabled in the main manifest. Debug/profile builds still allow it.
- Google Play requires new apps and updates to target Android 15 / API 35 or higher from August 31, 2025. This project now targets API 36.
