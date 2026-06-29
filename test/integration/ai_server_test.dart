import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/providers/ai_server.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

void main() {
  late AiServer aiServer;
  late int port;

  setUp(() async {
    aiServer = AiServer();
    port = 18511; // Use non-standard port to avoid conflicts
    final started = await aiServer.start(port: port);
    expect(started, true);
  });

  tearDown(() {
    aiServer.stop();
    aiServer.dispose();
  });

  group('AiServer HTTP Endpoints', () {
    test('GET /health returns 200 with status', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['status'], 'ok');
        expect(json['obs_connected'], false);
      } finally {
        client.close();
      }
    });

    test('GET /state returns full state JSON', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/state'));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['obs'], isNotNull);
        expect(json['platform'], isNotNull);
        expect(json['chat'], isNotNull);
        expect(json['obs']['connected'], false);
        expect(json['platform']['connected'], false);
        expect(json['chat']['total_messages'], 0);
      } finally {
        client.close();
      }
    });

    test('POST /command with valid command returns success', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Test'}}));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['success'], false); // OBS not connected
        expect(json['message'], 'OBS not connected');
      } finally {
        client.close();
      }
    });

    test('POST /command with missing command returns 400', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({}));
        final response = await request.close();
        expect(response.statusCode, 400);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['error'], 'Missing command');
      } finally {
        client.close();
      }
    });

    test('GET /overlay returns HTML', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/overlay'));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        expect(body, contains('<!DOCTYPE html>'));
        expect(body, contains('SCP Overlay'));
        expect(body, contains('status-bar'));
        expect(body, contains('chat-list'));
      } finally {
        client.close();
      }
    });

    test('GET /auth/callback without code returns error page', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/auth/callback'));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        expect(body, contains('Authorization failed'));
        expect(body, contains('No code received'));
      } finally {
        client.close();
      }
    });

    test('state reflects OBS connection when set', () async {
      final obs = ObsController();
      aiServer.setObs(obs);

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/state'));
        final response = await request.close();
        expect(response.statusCode, 200);

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['obs']['connected'], false);
      } finally {
        client.close();
        obs.dispose();
      }
    });
  });
}
