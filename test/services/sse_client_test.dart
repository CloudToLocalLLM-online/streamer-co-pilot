import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:streamer_co_pilot/services/sse_client.dart';

/// A mock http.Client that returns a pre-configured response.
class _MockHttpClient extends http.BaseClient {
  http.StreamedResponse? response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (response != null) return response!;
    throw Exception('No mock response configured');
  }
}

/// Helper to create a [http.StreamedResponse] from a list of SSE lines.
http.StreamedResponse _responseFromLines(List<String> lines) {
  final bytes = lines.map((l) => utf8.encode('$l\n')).expand((e) => e).toList();
  final controller = StreamController<List<int>>();
  controller.add(bytes);
  controller.close();
  return http.StreamedResponse(
    http.ByteStream(controller.stream),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

void main() {
  group('SseClient', () {
    test('constructor sets url', () {
      final client = SseClient('http://localhost:8510');
      expect(client, isNotNull);
      client.disconnect();
    });

    test('disconnect closes cleanly when not connected', () {
      final client = SseClient('http://localhost:8510');
      expect(() => client.disconnect(), returnsNormally);
    });

    test('disconnect is idempotent', () {
      final client = SseClient('http://localhost:8510');
      client.disconnect();
      client.disconnect();
      client.disconnect();
      expect(() => client.disconnect(), returnsNormally);
    });

    group('SSE parsing (1.9.1, 1.9.2)', () {
      test('parses event:data format correctly', () async {
        final mockClient = _MockHttpClient();
        final sseClient = SseClient('http://localhost:8510', httpClient: mockClient);

        final lines = [
          'event: status',
          'data: {"status":"live","viewers":42}',
          '',
          'event: chat',
          'data: {"user":"testuser","text":"hello"}',
          '',
        ];
        mockClient.response = _responseFromLines(lines);

        final events = await sseClient.connect().toList();
        expect(events, hasLength(2));
        expect(events[0], 'status\x00{"status":"live","viewers":42}');
        expect(events[1], 'chat\x00{"user":"testuser","text":"hello"}');

        sseClient.disconnect();
      });

      test('skips SSE comment lines (heartbeat)', () async {
        final mockClient = _MockHttpClient();
        final sseClient = SseClient('http://localhost:8510', httpClient: mockClient);

        final lines = [
          ': heartbeat',
          ': another comment',
          'event: status',
          'data: {"status":"live"}',
          ': heartbeat',
          '',
        ];
        mockClient.response = _responseFromLines(lines);

        final events = await sseClient.connect().toList();
        // Only the event:data pair should be yielded
        expect(events, hasLength(1));
        expect(events[0], 'status\x00{"status":"live"}');

        sseClient.disconnect();
      });

      test('parses data without event type', () async {
        final mockClient = _MockHttpClient();
        final sseClient = SseClient('http://localhost:8510', httpClient: mockClient);

        final lines = [
          'data: {"user":"testuser","text":"hello"}',
          '',
        ];
        mockClient.response = _responseFromLines(lines);

        final events = await sseClient.connect().toList();
        expect(events, hasLength(1));
        // When no event type, just the data is yielded
        expect(events[0], '{"user":"testuser","text":"hello"}');

        sseClient.disconnect();
      });

      test('handles multiple data lines for same event', () async {
        final mockClient = _MockHttpClient();
        final sseClient = SseClient('http://localhost:8510', httpClient: mockClient);

        final lines = [
          'event: status',
          'data: {"status":"live"}',
          'event: status',
          'data: {"status":"offline"}',
          '',
        ];
        mockClient.response = _responseFromLines(lines);

        final events = await sseClient.connect().toList();
        expect(events, hasLength(2));
        expect(events[0], 'status\x00{"status":"live"}');
        expect(events[1], 'status\x00{"status":"offline"}');

        sseClient.disconnect();
      });

      test('handles only comment lines (no events)', () async {
        final mockClient = _MockHttpClient();
        final sseClient = SseClient('http://localhost:8510', httpClient: mockClient);

        final lines = [
          ': heartbeat',
          ': keepalive',
          ': ping',
          '',
        ];
        mockClient.response = _responseFromLines(lines);

        final events = await sseClient.connect().toList();
        expect(events, isEmpty);

        sseClient.disconnect();
      });
    });
  });
}
