// HTTP client for the Streamer Co-Pilot AgentServer.
//
// Provides a clean interface for external agents (Hermes, OpenClaw, custom)
// to read state and send commands via the REST + SSE API.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Represents the full state snapshot from `/state`.
class AgentState {
  final bool obsConnected;
  final String? currentScene;
  final List<String> scenes;
  final bool streaming;
  final bool recording;
  final int streamDurationSec;
  final List<ObsSource> sources;
  final List<AudioChannel> audioChannels;
  final bool platformConnected;
  final int chatMessageCount;
  final List<String> recentChatPreview;

  const AgentState({
    required this.obsConnected,
    this.currentScene,
    required this.scenes,
    required this.streaming,
    required this.recording,
    required this.streamDurationSec,
    required this.sources,
    required this.audioChannels,
    required this.platformConnected,
    required this.chatMessageCount,
    required this.recentChatPreview,
  });

  factory AgentState.fromJson(Map<String, dynamic> json) {
    final obs = json['obs'] as Map<String, dynamic>? ?? {};
    final platform = json['platform'] as Map<String, dynamic>? ?? {};
    final chat = json['chat'] as Map<String, dynamic>? ?? {};

    return AgentState(
      obsConnected: obs['connected'] as bool? ?? false,
      currentScene: obs['current_scene'] as String?,
      scenes: (obs['scenes'] as List<dynamic>?)?.cast<String>() ?? [],
      streaming: obs['streaming'] as bool? ?? false,
      recording: obs['recording'] as bool? ?? false,
      streamDurationSec: obs['stream_duration_sec'] as int? ?? 0,
      sources: (obs['sources'] as List<dynamic>?)
              ?.map((s) => ObsSource.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      audioChannels: (obs['audio_channels'] as List<dynamic>?)
              ?.map((c) => AudioChannel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      platformConnected: platform['connected'] as bool? ?? false,
      chatMessageCount: chat['total_messages'] as int? ?? 0,
      recentChatPreview: (chat['recent'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// OBS source information.
class ObsSource {
  final String name;
  final bool enabled;
  final double volumeMul;
  final double volumeDb;
  final bool muted;
  final double audioBalance;
  final int audioSyncOffset;
  final int audioMonitorType;
  final List<int> audioTracks;

  const ObsSource({
    required this.name,
    required this.enabled,
    required this.volumeMul,
    required this.volumeDb,
    required this.muted,
    required this.audioBalance,
    required this.audioSyncOffset,
    required this.audioMonitorType,
    required this.audioTracks,
  });

  factory ObsSource.fromJson(Map<String, dynamic> json) => ObsSource(
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        volumeMul: (json['volume_mul'] as num?)?.toDouble() ?? 1.0,
        volumeDb: (json['volume_db'] as num?)?.toDouble() ?? 0.0,
        muted: json['muted'] as bool? ?? false,
        audioBalance: (json['audio_balance'] as num?)?.toDouble() ?? 0.0,
        audioSyncOffset: json['audio_sync_offset'] as int? ?? 0,
        audioMonitorType: json['audio_monitor_type'] as int? ?? 0,
        audioTracks: (json['audio_tracks'] as List<dynamic>?)?.cast<int>() ?? [],
      );
}

/// Audio channel (logical: microphone or music/desktop).
class AudioChannel {
  final String type; // 'microphone' or 'music_desktop'
  final String name;
  final String sourceName;
  final bool sourceFound;
  final double volumeMul;
  final double volumeDb;
  final bool muted;
  final double audioBalance;
  final int audioSyncOffset;
  final int audioMonitorType;
  final List<int> audioTracks;

  const AudioChannel({
    required this.type,
    required this.name,
    required this.sourceName,
    required this.sourceFound,
    required this.volumeMul,
    required this.volumeDb,
    required this.muted,
    required this.audioBalance,
    required this.audioSyncOffset,
    required this.audioMonitorType,
    required this.audioTracks,
  });

  factory AudioChannel.fromJson(Map<String, dynamic> json) => AudioChannel(
        type: json['type'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sourceName: json['source_name'] as String? ?? '',
        sourceFound: json['source_found'] as bool? ?? false,
        volumeMul: (json['volume_mul'] as num?)?.toDouble() ?? 1.0,
        volumeDb: (json['volume_db'] as num?)?.toDouble() ?? 0.0,
        muted: json['muted'] as bool? ?? false,
        audioBalance: (json['audio_balance'] as num?)?.toDouble() ?? 0.0,
        audioSyncOffset: json['audio_sync_offset'] as int? ?? 0,
        audioMonitorType: json['audio_monitor_type'] as int? ?? 0,
        audioTracks: (json['audio_tracks'] as List<dynamic>?)?.cast<int>() ?? [],
      );
}

/// Result of a command execution.
class CommandResult {
  final bool success;
  final String? message;

  const CommandResult({required this.success, this.message});

  factory CommandResult.fromJson(Map<String, dynamic> json) => CommandResult(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
      );
}

/// SSE event received from the event stream.
class SseEvent {
  final String eventType;
  final Map<String, dynamic> data;

  const SseEvent({required this.eventType, required this.data});

  factory SseEvent.fromRaw(String raw) {
    String? eventType;
    Map<String, dynamic>? data;

    for (final line in raw.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7);
      } else if (line.startsWith('data: ')) {
        try {
          data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        } catch (_) {
          data = {'raw': line.substring(6)};
        }
      }
    }

    return SseEvent(
      eventType: eventType ?? 'unknown',
      data: data ?? {},
    );
  }
}

/// Client for the AgentServer REST + SSE API.
class AgentClient {
  final String baseUrl;
  final http.Client _httpClient;
  final int ssePort;
  HttpClient? _sseHttpClient;
  StreamSubscription? _sseSubscription;
  final StreamController<SseEvent> _eventController = StreamController<SseEvent>.broadcast();

  AgentClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.ssePort = 8512,
  }) : _httpClient = httpClient ?? http.Client();

  /// Stream of real-time SSE events (obs_state, chat_message, platform_status, channel_event).
  Stream<SseEvent> get events => _eventController.stream;

  /// GET /health — simple health check.
  Future<bool> healthCheck() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// GET /state — full state snapshot for the agent.
  Future<AgentState> getState() async {
    final response = await _httpClient
        .get(Uri.parse('$baseUrl/state'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to get state: ${response.statusCode}');
    }
    return AgentState.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// POST /command — execute an agent command.
  Future<CommandResult> sendCommand(String command, Map<String, dynamic> params) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/command'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'command': command, 'params': params}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Command failed: ${response.statusCode} ${response.body}');
    }
    return CommandResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Connect to the SSE event stream on port + 1.
  Future<void> connectEvents() async {
      final sseUrl = '${baseUrl.replaceFirst(RegExp(r':\\d+$'), ':$ssePort')}/events/stream';
      final request = http.Request('get', Uri.parse(sseUrl));
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw Exception('SSE connection failed: ${response.statusCode}');
    }

    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n\n');
      buffer.clear();
      buffer.write(lines.last); // Keep incomplete event

      for (final eventRaw in lines.take(lines.length - 1)) {
        if (eventRaw.trim().isNotEmpty && !eventRaw.startsWith(':')) {
          _eventController.add(SseEvent.fromRaw(eventRaw));
        }
      }
    }
  }

  /// Disconnect from SSE and close HTTP client.
  Future<void> close() async {
    await _sseSubscription?.cancel();
    _sseHttpClient?.close(force: true);
    _httpClient.close();
    await _eventController.close();
  }
}