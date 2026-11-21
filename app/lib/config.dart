/// Where the app finds the Dahaby backend.
///
/// Override at build time:
///   flutter run --dart-define=BACKEND_URL=http://192.168.1.10:8080
///
/// On the Android emulator, the host machine is http://10.0.2.2:8080.
const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8080',
);

/// WebSocket address derived from [backendUrl] (http -> ws, https -> wss).
Uri get pricesSocketUri {
  final base = Uri.parse(backendUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '/ws',
  );
}
