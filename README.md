# lerolove

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend setup (Firebase)
- Ensure the Firebase project `love-connect-68400` is selected.
- Deploy rules and indexes:
  - `firebase deploy --only firestore:rules,firestore:indexes,storage`
- For iOS, add `ios/Runner/GoogleService-Info.plist` from the Firebase console.
