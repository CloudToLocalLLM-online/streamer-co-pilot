import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import '../providers/obs_controller.dart';
import '../platforms/stream_platform.dart';
import '../models/chat_message.dart';

/// Full state snapshot sent to the AI.
class AiStateSnapshot {
  final ObsState obs;
  final bool platformConnected;
  final int chatMessageCount;
  final List<String> recentChatPreview;

  const AiStateSnapshot({
    required this.obs,
    required this.platformConnected,
    this.chatMessageCount = 0,
    this.recentChatPreview = const [],
  });

  Map<String, dynamic> toJson() => {
    'obs': {
      'connected': obs.connected,
      'current_scene': obs.currentScene,
      'scenes': obs.scenes,
      'streaming': obs.streaming,
      'recording': obs.recording,
      'stream_duration_sec': obs.streamDurationSec,
      'sources': obs.sources.map((s) => {
        'name': s.name,
        'enabled': s.enabled,
      }).toList(),
    },
    'platform': {
      'connected': platformConnected,
    },
    'chat': {
      'total_messages': chatMessageCount,
      'recent': recentChatPreview,
    },
  };
}

/// Result of an AI command.
class AiCommandResult {
  final bool success;
  final String? message;

  const AiCommandResult({required this.success, this.message});

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
  };
}

/// Embedded HTTP server that exposes stream state and accepts AI commands.
///
/// Hermes/Aigent connects here to read state and send actions.
class AiServer extends ChangeNotifier {
  final ObsController _obs;
  final StreamPlatform? _platform;

  HttpServer? _server;
  int _port = 8511;
  bool _running = false;
  bool get running => _running;
  int get port => _port;

  // Chat message buffer for context
  final List<ChatMessage> _chatBuffer = [];
  static const _maxChatBuffer = 100;

  AiServer(this._obs, this._platform) {
    _platform?.chatStream.listen(_onChatMessage);
  }

  void _onChatMessage(ChatMessage msg) {
    _chatBuffer.add(msg);
    if (_chatBuffer.length > _maxChatBuffer) {
      _chatBuffer.removeAt(0);
    }
  }

  /// Build the current state snapshot for the AI.
  AiStateSnapshot buildSnapshot() {
    return AiStateSnapshot(
      obs: _obs.state,
      platformConnected: _platform?.connected ?? false,
      chatMessageCount: _chatBuffer.length,
      recentChatPreview: _chatBuffer
          .map((m) => '${m.user}: ${m.text}')
          .toList()
          .reversed
          .take(10)
          .toList(),
    );
  }

  /// Execute a command from the AI.
  Future<AiCommandResult> executeCommand(String command, Map<String, dynamic> params) async {
    switch (command) {
      // ── OBS commands ──
      case 'switch_scene':
        final name = params['scene'] as String?;
        if (name == null) return const AiCommandResult(success: false, message: 'Missing scene');
        final ok = await _obs.switchScene(name);
        return AiCommandResult(success: ok, message: ok ? 'Switched to $name' : 'Failed');

      case 'toggle_source':
        final name = params['source'] as String?;
        if (name == null) return const AiCommandResult(success: false, message: 'Missing source');
        final ok = await _obs.toggleSource(name);
        return AiCommandResult(success: ok, message: ok ? 'Toggled $name' : 'Failed');

      case 'set_source':
        final name = params['source'] as String?;
        final enabled = params['enabled'] as bool?;
        if (name == null || enabled == null) {
          return const AiCommandResult(success: false, message: 'Missing source or enabled');
        }
        final ok = await _obs.setSourceEnabled(name, enabled);
        return AiCommandResult(success: ok, message: ok
            ? '${enabled ? "Enabled" : "Disabled"} $name'
            : 'Failed');

      case 'toggle_stream':
        final ok = await _obs.toggleStream();
        return AiCommandResult(success: ok, message: ok ? 'Toggled stream' : 'Failed');

      case 'toggle_recording':
        final ok = await _obs.toggleRecording();
        return AiCommandResult(success: ok, message: ok ? 'Toggled recording' : 'Failed');

      // ── Chat commands ──
      case 'send_message':
        final text = params['message'] as String?;
        if (text == null || text.isEmpty) {
          return const AiCommandResult(success: false, message: 'Missing message');
        }
        final ok = await _platform?.sendMessage(text) ?? false;
        return AiCommandResult(success: ok, message: ok ? 'Sent' : 'Failed');

      case 'timeout':
        final user = params['user'] as String?;
        if (user == null) return const AiCommandResult(success: false, message: 'Missing user');
        final ok = await _platform?.timeoutUser(user) ?? false;
        return AiCommandResult(success: ok, message: ok ? 'Timed out $user' : 'Failed');

      case 'ban':
        final user = params['user'] as String?;
        if (user == null) return const AiCommandResult(success: false, message: 'Missing user');
        final ok = await _platform?.banUser(user) ?? false;
        return AiCommandResult(success: ok, message: ok ? 'Banned $user' : 'Failed');

      default:
        return AiCommandResult(success: false, message: 'Unknown command: $command');
    }
  }

  // ── HTTP Server ──

  Future<bool> start({int port = 8511}) async {
    _port = port;
    try {
      final router = shelf_router.Router();

      // GET /state — full state snapshot for the AI
      router.get('/state', (request) {
        final snapshot = buildSnapshot();
        return shelf.Response.ok(
          jsonEncode(snapshot.toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // POST /command — execute an AI command
      router.post('/command', (request) async {
        final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        final command = body['command'] as String?;
        final params = body['params'] as Map<String, dynamic>? ?? {};
        if (command == null) {
          return shelf.Response.badRequest(
            body: jsonEncode({'error': 'Missing command'}),
          );
        }
        final result = await executeCommand(command, params);
        return shelf.Response.ok(
          jsonEncode(result.toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // GET /health — simple health check
      router.get('/health', (request) {
        return shelf.Response.ok(
          jsonEncode({'status': 'ok', 'obs_connected': _obs.state.connected}),
          headers: {'Content-Type': 'application/json'},
        );
      });

      // GET /overlay — serve the OBS browser source overlay
      router.get('/overlay', (request) {
        return shelf.Response.ok(
          _overlayHtml,
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      });

      _server = await shelf_io.serve(router, '0.0.0.0', port);
      _running = true;
      notifyListeners();
      debugPrint('[AiServer] Started on port $port');
      return true;
    } catch (e) {
      debugPrint('[AiServer] Failed to start: $e');
      _running = false;
      notifyListeners();
      return false;
    }
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
    _running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Embedded OBS overlay HTML (served at /overlay)
const _overlayHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SCP Overlay</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Inter', -apple-system, sans-serif;
    background: transparent;
    overflow: hidden;
    color: #fff;
  }
  #status-bar {
    display: flex; align-items: center; gap: 12px;
    padding: 8px 14px;
    background: rgba(0,0,0,0.75);
    backdrop-filter: blur(8px);
    border-radius: 10px;
    margin: 10px;
    font-size: 13px;
    position: fixed; top: 0; left: 0; right: 0;
    z-index: 100;
  }
  .status-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .status-dot.live { background: #ff4444; box-shadow: 0 0 8px #ff444488; }
  .status-dot.offline { background: #666; }
  #status-label { font-weight: 700; }
  #status-label.live { color: #ff4444; }
  #viewer-count { color: #aaa; font-size: 12px; }
  #stream-title { flex: 1; text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #ccc; font-size: 12px; }
  #chat-container { position: fixed; bottom: 0; left: 10px; right: 10px; max-height: 60vh; overflow: hidden; padding: 4px; }
  #chat-list { display: flex; flex-direction: column-reverse; gap: 2px; max-height: calc(60vh - 10px); overflow-y: auto; scrollbar-width: none; }
  #chat-list::-webkit-scrollbar { display: none; }
  .chat-msg { background: rgba(0,0,0,0.6); backdrop-filter: blur(4px); padding: 6px 12px; border-radius: 8px; font-size: 14px; line-height: 1.4; animation: fadeIn 0.3s ease-out; display: flex; align-items: baseline; gap: 6px; }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
  .chat-msg .time { color: #888; font-size: 11px; }
  .chat-msg .user { color: #b388ff; font-weight: 600; }
  .chat-msg .text { color: #eee; word-break: break-word; }
  .chat-empty { color: #666; font-size: 13px; text-align: center; padding: 20px; }
</style>
</head>
<body>
<div id="status-bar">
  <div class="status-dot offline"></div>
  <span id="status-label">Connecting...</span>
  <span id="viewer-count"></span>
  <span id="stream-title"></span>
</div>
<div id="chat-container">
  <div id="chat-list"><div class="chat-empty">💬 Chat will appear here...</div></div>
</div>
<script>
const API = window.location.origin;
const chatList = document.getElementById('chat-list');
const statusDot = document.querySelector('.status-dot');
const statusLabel = document.getElementById('status-label');
const viewerCount = document.getElementById('viewer-count');
const streamTitle = document.getElementById('stream-title');
async function fetchState() {
  try {
    const res = await fetch(API + '/state', { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return;
    const data = await res.json();
    if (data.obs) {
      statusDot.className = 'status-dot ' + (data.obs.streaming ? 'live' : 'offline');
      statusLabel.textContent = data.obs.streaming ? '🔴 LIVE' : '⚫ OFFLINE';
      statusLabel.className = data.obs.streaming ? 'live' : '';
    }
  } catch (_) {}
}
fetchState();
setInterval(fetchState, 5000);
</script>
</body>
</html>
''';
