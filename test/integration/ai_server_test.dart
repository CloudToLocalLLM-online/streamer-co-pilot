import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_co_pilot/providers/agent_server.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

void main() {
  group('AgentServer HTTP Endpoints (3.2)', () {
    late AgentServer agentServer;
    late int port;

    setUp(() async {
      agentServer = AgentServer();
      port = 18511;
      final started = await agentServer.start(port: port);
      expect(started, true);
    });

    tearDown(() {
      agentServer.stop();
      agentServer.dispose();
    });

    test('3.2.1 — GET /health returns 200 with status', () async {
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

    test('3.2.2 — GET /state returns full state JSON', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/state'));
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['obs'], isA<Map<String, dynamic>>());
        expect(json['platform'], isA<Map<String, dynamic>>());
        expect(json['chat'], isA<Map<String, dynamic>>());
        expect(json['obs']['connected'], false);
        expect(json['platform']['connected'], false);
        expect(json['chat']['total_messages'], 0);
      } finally {
        client.close();
      }
    });

    test('3.2.3 — POST /command with valid command returns success', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'command': 'switch_scene', 'params': {'scene': 'Test'}}));
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['success'], false);
        expect(json['message'], 'OBS not connected');
      } finally {
        client.close();
      }
    });

    test('3.2.4 — POST /command with missing command returns 400', () async {
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

    test('3.2.5 — GET /overlay returns HTML', () async {
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
      agentServer.setObs(obs);
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

    test('health reflects OBS connection when set', () async {
      final obs = ObsController();
      agentServer.setObs(obs);
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['obs_connected'], false);
      } finally {
        client.close();
        obs.dispose();
      }
    });

    test('POST /command with unknown command returns error', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'command': 'nonexistent', 'params': {}}));
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['success'], false);
        expect(json['message'], contains('Unknown command'));
      } finally {
        client.close();
      }
    });

    test('POST /command with missing params defaults to empty', () async {
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'command': 'switch_scene'}));
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        expect(json['success'], false);
        expect(json['message'], 'Missing scene');
      } finally {
        client.close();
      }
    });
  });
}
