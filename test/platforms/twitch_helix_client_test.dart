import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:streamer_co_pilot/platforms/twitch_auth.dart';
import 'package:streamer_co_pilot/platforms/twitch_helix_client.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockTwitchAuth extends Mock implements TwitchAuth {}

class MockResponse extends Mock implements http.Response {}

void main() {
  late MockHttpClient mockHttp;
  late MockTwitchAuth mockAuth;
  late TwitchHelixClient client;

  setUp(() {
    mockHttp = MockHttpClient();
    mockAuth = MockTwitchAuth();

    // Default auth stubs
    when(() => mockAuth.ensureValidToken()).thenAnswer((_) async => true);
    when(() => mockAuth.accessToken).thenReturn('test-access-token');
    when(() => mockAuth.clientId).thenReturn('test-client-id');

    client = TwitchHelixClient(mockAuth, mockHttp);
  });

  group('TwitchHelixClient', () {
    group('resolveUserId()', () {
      test('parses response correctly', () async {
        final response = http.Response(
          jsonEncode({
            'data': [
              {'id': '12345', 'login': 'testuser', 'display_name': 'TestUser'},
            ],
          }),
          200,
        );

        when(() => mockHttp.get(
              Uri.parse('https://api.twitch.tv/helix/users?login=testuser'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final userId = await client.resolveUserId('testuser');

        expect(userId, '12345');
        verify(() => mockHttp.get(
              Uri.parse('https://api.twitch.tv/helix/users?login=testuser'),
              headers: any(named: 'headers'),
            )).called(1);
      });

      test('returns null on 404', () async {
        final response = http.Response(
          jsonEncode({'data': []}),
          404,
        );

        when(() => mockHttp.get(
              Uri.parse('https://api.twitch.tv/helix/users?login=nobody'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final userId = await client.resolveUserId('nobody');

        expect(userId, isNull);
      });

      test('returns null on HTTP error', () async {
        when(() => mockHttp.get(
              Uri.parse('https://api.twitch.tv/helix/users?login=erroruser'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Network error'));

        final userId = await client.resolveUserId('erroruser');

        expect(userId, isNull);
      });
    });

    group('fetchStreamStatus()', () {
      test('parses live stream response', () async {
        final startedAt = DateTime.now().subtract(const Duration(hours: 2));
        final response = http.Response(
          jsonEncode({
            'data': [
              {
                'id': '12345',
                'user_id': '98765',
                'user_login': 'testbroadcaster',
                'user_name': 'TestBroadcaster',
                'game_id': '123',
                'game_name': 'Just Chatting',
                'type': 'live',
                'title': 'My Awesome Stream',
                'viewer_count': 42,
                'started_at': startedAt.toIso8601String(),
                'language': 'en',
              },
            ],
          }),
          200,
        );

        when(() => mockHttp.get(
              Uri.parse(
                  'https://api.twitch.tv/helix/streams?user_id=broadcaster123'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final status = await client.fetchStreamStatus('broadcaster123');

        expect(status.live, true);
        expect(status.viewers, 42);
        expect(status.game, 'Just Chatting');
        expect(status.title, 'My Awesome Stream');
        expect(status.uptimeSec, greaterThanOrEqualTo(7190)); // ~2h
      });

      test('returns offline when no stream', () async {
        final response = http.Response(
          jsonEncode({'data': []}),
          200,
        );

        when(() => mockHttp.get(
              Uri.parse(
                  'https://api.twitch.tv/helix/streams?user_id=offlineuser'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final status = await client.fetchStreamStatus('offlineuser');

        expect(status.live, false);
        expect(status.viewers, 0);
        expect(status.game, '');
        expect(status.title, '');
      });

      test('returns offline on HTTP error', () async {
        when(() => mockHttp.get(
              Uri.parse(
                  'https://api.twitch.tv/helix/streams?user_id=erroruser'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Network error'));

        final status = await client.fetchStreamStatus('erroruser');

        expect(status.live, false);
        expect(status.viewers, 0);
      });
    });

    group('timeoutUser()', () {
      test('sends correct request body', () async {
        final response = http.Response('{}', 200);

        when(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.timeoutUser('broad1', 'mod1', 'user1',
            duration: 600);

        expect(result, true);
        verify(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: jsonEncode({
                'data': {
                  'user_id': 'user1',
                  'duration': 600,
                  'reason': 'Timed out via Streamer Co-Pilot',
                },
              }),
            )).called(1);
      });

      test('returns false on HTTP error', () async {
        when(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        final result =
            await client.timeoutUser('broad1', 'mod1', 'user1');

        expect(result, false);
      });
    });

    group('banUser()', () {
      test('sends correct request body', () async {
        final response = http.Response('{}', 200);

        when(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.banUser('broad1', 'mod1', 'user1');

        expect(result, true);
        verify(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: jsonEncode({
                'data': {
                  'user_id': 'user1',
                  'reason': 'Banned via Streamer Co-Pilot',
                },
              }),
            )).called(1);
      });

      test('returns false on HTTP error', () async {
        when(() => mockHttp.post(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        final result = await client.banUser('broad1', 'mod1', 'user1');

        expect(result, false);
      });
    });

    group('unbanUser()', () {
      test('sends correct DELETE request', () async {
        final response = http.Response('', 204);

        when(() => mockHttp.delete(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1&user_id=user1'),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.unbanUser('broad1', 'mod1', 'user1');

        expect(result, true);
        verify(() => mockHttp.delete(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1&user_id=user1'),
              headers: any(named: 'headers'),
            )).called(1);
      });

      test('returns false on HTTP error', () async {
        when(() => mockHttp.delete(
              Uri.parse(
                  'https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broad1&moderator_id=mod1&user_id=user1'),
              headers: any(named: 'headers'),
            )).thenThrow(Exception('Network error'));

        final result = await client.unbanUser('broad1', 'mod1', 'user1');

        expect(result, false);
      });
    });

    group('setChatMode()', () {
      test('sends correct PATCH body', () async {
        final response = http.Response('{}', 200);

        when(() => mockHttp.patch(
              Uri.parse(
                  'https://api.twitch.tv/helix/chat/settings?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result =
            await client.setChatMode('broad1', 'mod1', 'emote_mode', true);

        expect(result, true);
        verify(() => mockHttp.patch(
              Uri.parse(
                  'https://api.twitch.tv/helix/chat/settings?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: jsonEncode({'emote_mode': true}),
            )).called(1);
      });

      test('returns false on HTTP error', () async {
        when(() => mockHttp.patch(
              Uri.parse(
                  'https://api.twitch.tv/helix/chat/settings?broadcaster_id=broad1&moderator_id=mod1'),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        final result =
            await client.setChatMode('broad1', 'mod1', 'slow_mode', true);

        expect(result, false);
      });
    });
  });
}
