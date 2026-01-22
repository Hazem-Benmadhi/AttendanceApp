# Campus Face Recognition Mobile Client

Flutter application that authenticates campus staff or students before capturing a face photo for server-side recognition.

## Features

- Email/password login wired to REST backend via Dio.
- Demo credentials (tester@example.com / Password123!) available when backend is offline.
- Secure token persistence using flutter_secure_storage.
- Android camera capture with live preview, upload, and last-image recap.
- Offline demo mode simulates uploads when backend is unavailable.
- Provider-based auth gate routing between login and capture flow.

## Configuration

Set the backend base URL in [lib/core/config/app_config.dart](lib/core/config/app_config.dart) before building.

## Development

- Install dependencies: `flutter pub get`
- Static analysis: `dart analyze`
- Run widget tests: `flutter test`

## Next Up

- Add iOS camera support and tune capture resolution.
- Harden error handling, secure storage, and analytics once real endpoints are wired.
