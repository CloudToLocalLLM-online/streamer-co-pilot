import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Low-level SSE event stream client.
///
/// Connects to [url]/events/stream, feeds raw SSE lines as a [Stream<String>].
/// Supports connect timeout, read timeout, heartbeat-skip, and clean disconnect.
class SseClient {
  final String url;
  http.Client? _client;
  final http.Client? _injectedClient;
  Timer? _readTimeoutTimer;
  Timer? _connectTimeoutTimer;

  SseClient(this.url, {http.Client? httpClient}) : _injectedClient = httpClient;

  /// How long to wait for the initial HTTP response.
  static const _connectTimeout = Duration(seconds: 15);
  /// How long without any data before we consider the stream dead.
  static const _readTimeout = Duration(seconds: 30);

  Stream<String> connect() async* {
    _client = _injectedClient ?? http.Client();
    final request = http.Request('GET', Uri.parse('$url/events/stream'));

    final response = await _client!
        .send(request)
        .timeout(_connectTimeout, onTimeout: () {
      _client?.close();
      _client = null;
      throw TimeoutException('SSE connect timed out after $_connectTimeout');
    });

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String currentEvent = '';
    await for (final line in lines) {
      _readTimeoutTimer?.cancel();
      _readTimeoutTimer = Timer(_readTimeout, () {
        _readTimeoutTimer = null;
        disconnect();
      });

      // Skip SSE comment lines (heartbeat: ": heartbeat")
      if (line.startsWith(':')) continue;

      if (line.startsWith('event: ')) {
        currentEvent = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        yield currentEvent.isEmpty
            ? line.substring(6)
            : '$currentEvent\x00${line.substring(6)}';
        currentEvent = '';
      }
    }
  }

  void disconnect() {
    _readTimeoutTimer?.cancel();
    _readTimeoutTimer = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    _client?.close();
    _client = null;
  }
}