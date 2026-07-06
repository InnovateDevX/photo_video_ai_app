import 'package:http/http.dart' as http;

/// Singleton that tracks active HTTP clients used for Replicate API requests.
/// When [cancelAll] is called, all in-flight requests are immediately terminated.
class CancellationManager {
  static final CancellationManager _instance = CancellationManager._internal();
  factory CancellationManager() => _instance;
  CancellationManager._internal();

  final Set<http.Client> _activeClients = {};

  /// Creates a new [http.Client] and registers it for cancellation tracking.
  http.Client createClient() {
    final client = http.Client();
    _activeClients.add(client);
    return client;
  }

  /// Unregisters a client after its request completes (success or error).
  void unregisterClient(http.Client client) {
    _activeClients.remove(client);
  }

  /// Closes all tracked HTTP clients, immediately cancelling any in-flight requests.
  /// Call this when the app is minimized or exiting.
  void cancelAll() {
    for (final client in _activeClients) {
      client.close();
    }
    _activeClients.clear();
  }
}
