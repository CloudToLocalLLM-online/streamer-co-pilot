import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'twitch_auth.dart';

/// Stream status from Helix API.
class TwitchStreamStatus {
  final bool live;
  final int viewers;
  final String game;
  final String title;
  final int uptimeSec;

  const TwitchStreamStatus({
    this.live = false,
    this.viewers = 0,
    this.game = '',
    this.title = '',
    this.uptimeSec = 0,
  });
}

/// Twitch Helix API client.
///
/// Handles all REST API calls: stream status, user info, moderation.
class TwitchHelixClient {
  final TwitchAuth _auth;
  final http.Client _http = http.Client();

  TwitchHelixClient(this._auth);

  /// Headers for authenticated Helix requests.
  Future<Map<String, String>> _headers() async {
    await _auth.ensureValidToken();
    return {
      'Authorization': 'Bearer ${_auth.accessToken}',
      'Client-Id': _auth.clientId ?? '',
    };
  }

  /// Resolve a username to a user ID.
  Future<String?> resolveUserId(String login) async {
    try {
      final res = await _http.get(
        Uri.parse('https://api.twitch.tv/helix/users?login=$login'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final users = data['data'] as List<dynamic>;
        if (users.isNotEmpty) {
          return (users[0] as Map<String, dynamic>)['id'] as String;
        }
      }
    } catch (e) {
      debugPrint('[TwitchHelix] Resolve user error: $e');
    }
    return null;
  }

  /// Fetch stream status for a broadcaster.
  Future<TwitchStreamStatus> fetchStreamStatus(String broadcasterId) async {
    try {
      final res = await _http.get(
        Uri.parse('https://api.twitch.tv/helix/streams?user_id=$broadcasterId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final streams = data['data'] as List<dynamic>;
        if (streams.isNotEmpty) {
          final s = streams[0] as Map<String, dynamic>;
          final startedAt = DateTime.parse(s['started_at'] as String);
          return TwitchStreamStatus(
            live: true,
            viewers: s['viewer_count'] as int? ?? 0,
            game: s['game_name'] as String? ?? '',
            title: s['title'] as String? ?? '',
            uptimeSec: DateTime.now().difference(startedAt).inSeconds,
          );
        }
      }
      return const TwitchStreamStatus(live: false);
    } catch (e) {
      debugPrint('[TwitchHelix] Fetch stream status error: $e');
      return const TwitchStreamStatus();
    }
  }

  /// Timeout a user.
  Future<bool> timeoutUser(String broadcasterId, String moderatorId, String userId, {int duration = 300}) async {
    try {
      final res = await _http.post(
        Uri.parse('https://api.twitch.tv/helix/moderation/bans?broadcaster_id=$broadcasterId&moderator_id=$moderatorId'),
        headers: {
          ...await _headers(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'user_id': userId,
            'duration': duration,
            'reason': 'Timed out via Streamer Co-Pilot',
          },
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TwitchHelix] Timeout error: $e');
      return false;
    }
  }

  /// Ban a user.
  Future<bool> banUser(String broadcasterId, String moderatorId, String userId) async {
    try {
      final res = await _http.post(
        Uri.parse('https://api.twitch.tv/helix/moderation/bans?broadcaster_id=$broadcasterId&moderator_id=$moderatorId'),
        headers: {
          ...await _headers(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'user_id': userId,
            'reason': 'Banned via Streamer Co-Pilot',
          },
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TwitchHelix] Ban error: $e');
      return false;
    }
  }

  /// Unban a user.
  Future<bool> unbanUser(String broadcasterId, String moderatorId, String userId) async {
    try {
      final res = await _http.delete(
        Uri.parse('https://api.twitch.tv/helix/moderation/bans?broadcaster_id=$broadcasterId&moderator_id=$moderatorId&user_id=$userId'),
        headers: await _headers(),
      );
      return res.statusCode == 204;
    } catch (e) {
      debugPrint('[TwitchHelix] Unban error: $e');
      return false;
    }
  }

  /// Set chat mode (slow, emote-only, subscribers-only).
  Future<bool> setChatMode(String broadcasterId, String moderatorId, String mode, bool enabled) async {
    try {
      final res = await _http.patch(
        Uri.parse('https://api.twitch.tv/helix/chat/settings?broadcaster_id=$broadcasterId&moderator_id=$moderatorId'),
        headers: {
          ...await _headers(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({mode: enabled}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[TwitchHelix] Set chat mode error: $e');
      return false;
    }
  }

  /// Clear chat (requires moderator:manage:chat_settings scope).
  Future<bool> clearChat(String broadcasterId, String moderatorId) async {
    try {
      final res = await _http.delete(
        Uri.parse('https://api.twitch.tv/helix/chat/ban?broadcaster_id=$broadcasterId&moderator_id=$moderatorId'),
        headers: await _headers(),
      );
      return res.statusCode == 204;
    } catch (e) {
      debugPrint('[TwitchHelix] Clear chat error: $e');
      return false;
    }
  }

  void dispose() {
    _http.close();
  }
}
