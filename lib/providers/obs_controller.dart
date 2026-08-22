import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:obs_websocket/obs_websocket.dart' as obs;
import 'package:obs_websocket/event.dart' as obs_event;
import 'package:shared_preferences/shared_preferences.dart';

/// Logical audio channels for stream management
enum AudioChannelType {
  microphone,    // Voice input
  musicDesktop,  // System/game audio
}

/// Configuration for a logical audio channel
class AudioChannelConfig {
  final AudioChannelType type;
  final String name;                    // User-facing name
  final List<String> sourcePatterns;    // Regex patterns to match OBS source names
  final String? mappedSourceName;       // Currently mapped OBS source (persisted)

  const AudioChannelConfig({
    required this.type,
    required this.name,
    required this.sourcePatterns,
    this.mappedSourceName,
  });

  /// Default configurations
  static const defaultMic = AudioChannelConfig(
    type: AudioChannelType.microphone,
    name: 'Microphone',
    sourcePatterns: [r'(?i)mic(rophone)?', r'(?i)voice', r'(?i)input'],
  );

  static const defaultMusic = AudioChannelConfig(
    type: AudioChannelType.musicDesktop,
    name: 'Music/Desktop',
    sourcePatterns: [r'(?i)desktop', r'(?i)system audio', r'(?i)application audio', r'(?i)game audio', r'(?i)music'],
  );

  AudioChannelConfig copyWith({String? mappedSourceName}) {
    return AudioChannelConfig(
      type: type,
      name: name,
      sourcePatterns: sourcePatterns,
      mappedSourceName: mappedSourceName ?? this.mappedSourceName,
    );
  }
}

/// Runtime state of a logical audio channel (aggregated from mapped source)
class AudioChannelState {
  final AudioChannelType type;
  final String name;
  final String? sourceName;          // Currently mapped OBS source
  final bool sourceFound;
  final double? volumeMul;
  final double? volumeDb;
  final bool? muted;
  final double? audioBalance;
  final int? audioSyncOffset;
  final int? audioMonitorType;
  final int? audioTracks;

  const AudioChannelState({
    required this.type,
    required this.name,
    this.sourceName,
    this.sourceFound = false,
    this.volumeMul,
    this.volumeDb,
    this.muted,
    this.audioBalance,
    this.audioSyncOffset,
    this.audioMonitorType,
    this.audioTracks,
  });

  /// Empty state when no source mapped/found
  factory AudioChannelState.empty(AudioChannelConfig config) {
    return AudioChannelState(
      type: config.type,
      name: config.name,
      sourceFound: false,
    );
  }
}

/// State of a single OBS source (camera, mic, etc.)
class ObsSourceState {
  final String name;
  final bool enabled;
  final int itemId;
  final double? volumeMul;      // 0.0 to ~20.0 (multiplier)
  final double? volumeDb;       // -100 to +26 dB
  final bool? muted;
  final double? audioBalance;   // -1.0 (left) to 1.0 (right)
  final int? audioSyncOffset;   // ms
  final int? audioMonitorType;  // 0=off, 1=monitor only, 2=monitor and output
  final int? audioTracks;       // bitmask

  const ObsSourceState({
    required this.name,
    required this.enabled,
    required this.itemId,
    this.volumeMul,
    this.volumeDb,
    this.muted,
    this.audioBalance,
    this.audioSyncOffset,
    this.audioMonitorType,
    this.audioTracks,
  });
}

/// Full OBS state snapshot
class ObsState {
  final bool connected;
  final String? currentScene;
  final List<String> scenes;
  final List<ObsSourceState> sources;
  final bool streaming;
  final bool recording;
  final int? streamDurationSec;
  final List<AudioChannelState> audioChannels;  // Logical audio channels

  const ObsState({
    this.connected = false,
    this.currentScene,
    this.scenes = const [],
    this.sources = const [],
    this.streaming = false,
    this.recording = false,
    this.streamDurationSec,
    this.audioChannels = const [],
  });
}

/// Controls OBS Studio via obs-websocket.
class ObsController extends ChangeNotifier {
  ObsController() {
    _loadChannelConfigs();
  }

  obs.ObsWebSocket? _obs;
  ObsState _state = const ObsState();
  ObsState get state => _state;

  String _host = 'localhost';
  int _port = 4455;
  String _password = '';

  final bool _autoReconnect = true;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  // ── Config ──

  void configure({String host = 'localhost', int port = 4455, String password = ''}) {
    _host = host;
    _port = port;
    _password = password;
  }

  // ── Audio Channel Config ──

  AudioChannelConfig _micConfig = AudioChannelConfig.defaultMic;
  AudioChannelConfig _musicConfig = AudioChannelConfig.defaultMusic;

  AudioChannelConfig get micConfig => _micConfig;
  AudioChannelConfig get musicConfig => _musicConfig;

  void updateMicConfig(AudioChannelConfig config) {
    _micConfig = config;
    _saveChannelConfigs();
    notifyListeners();
  }

  void updateMusicConfig(AudioChannelConfig config) {
    _musicConfig = config;
    _saveChannelConfigs();
    notifyListeners();
  }

  Future<void> _saveChannelConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('obs_channel_configs', jsonEncode({
        'microphone': _micConfig.mappedSourceName,
        'musicDesktop': _musicConfig.mappedSourceName,
      }));
    } catch (e) {
      debugPrint('[ObsController] failed to save channel configs: $e');
    }
  }

  Future<void> _loadChannelConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString('obs_host');
      final port = prefs.getInt('obs_port');
      final password = prefs.getString('obs_password');
      if (host != null) _host = host;
      if (port != null) _port = port;
      if (password != null) _password = password;
      final raw = prefs.getString('obs_channel_configs');
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final mic = map['microphone'] as String?;
      final music = map['musicDesktop'] as String?;
      if (mic != null) {
        _micConfig = _micConfig.copyWith(mappedSourceName: mic);
      }
      if (music != null) {
        _musicConfig = _musicConfig.copyWith(mappedSourceName: music);
      }
    } catch (e) {
      debugPrint('[ObsController] failed to load channel configs: $e');
    }
  }

  // ── Connection ──

  Future<bool> connect() async {
    _reconnectTimer?.cancel();
    try {
      _obs = await obs.ObsWebSocket.connect(
        'ws://$_host:$_port',
        password: _password.isEmpty ? null : _password,
        autoReconnect: _autoReconnect,
      );
      _state = ObsState(connected: true);
      notifyListeners();
      _startPolling();
      return true;
    } catch (e) {
      debugPrint('[ObsController] connect failed: $e');
      _state = ObsState(connected: false);
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _obs?.close();
    _obs = null;
    _state = const ObsState();
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () => connect());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    _refresh();
  }

  Future<void> _refresh() async {
    if (_obs == null) return;
    try {
      final sceneList = await _obs!.scenes.getSceneList();
      final currentScene = await _obs!.scenes.getCurrentProgramScene();
      final streamStatus = await _obs!.stream.getStreamStatus();
      final recordStatus = await _obs!.record.getRecordStatus();

      // Get source list with visibility from current scene
      final sources = <ObsSourceState>[];
      try {
        final items = await _obs!.sceneItems.getSceneItemList(currentScene);
        for (final item in items) {
          // Fetch audio properties for each source
          double? volMul;
          double? volDb;
          bool? muted;
          double? balance;
          int? syncOffset;
          int? monitorType;
          int? tracks;
          try {
            final volResp = await _obs!.inputs.getInputVolume(inputName: item.sourceName);
            volMul = volResp.inputVolumeMul;
            volDb = volResp.inputVolumeDb;
            final muteResp = await _obs!.inputs.getInputMute(item.sourceName);
            muted = muteResp;
            final balResp = await _obs!.inputs.getInputAudioBalance(inputName: item.sourceName);
            balance = balResp.inputAudioBalance;
            final syncResp = await _obs!.inputs.getInputAudioSyncOffset(inputName: item.sourceName);
            syncOffset = syncResp.inputAudioSyncOffset;
            final monResp = await _obs!.inputs.getInputAudioMonitorType(inputName: item.sourceName);
            monitorType = monResp.monitorType.index;
            final trackResp = await _obs!.inputs.getInputAudioTracks(inputName: item.sourceName);
            tracks = trackResp.inputAudioTracks;
          } catch (_) {
            // Audio queries may fail for non-audio sources; ignore
          }

          sources.add(ObsSourceState(
            name: item.sourceName,
            enabled: item.sceneItemEnabled,
            itemId: item.sceneItemId,
            volumeMul: volMul,
            volumeDb: volDb,
            muted: muted,
            audioBalance: balance,
            audioSyncOffset: syncOffset,
            audioMonitorType: monitorType,
            audioTracks: tracks,
          ));
        }
      } catch (_) {
        // Scene might be empty or not exist
      }

      // Build logical audio channels
      final audioChannels = _buildAudioChannels(sources);

      _state = ObsState(
        connected: true,
        currentScene: currentScene,
        scenes: sceneList.scenes.map((s) => s.sceneName).toList(),
        sources: sources,
        streaming: streamStatus.outputActive,
        recording: recordStatus.outputActive,
        streamDurationSec: streamStatus.outputDuration ~/ 1000,
        audioChannels: audioChannels,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[ObsController] refresh error: $e');
      _state = ObsState(connected: false);
      notifyListeners();
      _scheduleReconnect();
    }
  }

  List<AudioChannelState> _buildAudioChannels(List<ObsSourceState> sources) {
    final channels = <AudioChannelState>[];
    
    // Try to find mapped source for mic channel
    String? micSourceName = _micConfig.mappedSourceName;
    if (micSourceName == null) {
      // Auto-detect
      for (final source in sources) {
        for (final pattern in _micConfig.sourcePatterns) {
          if (RegExp(pattern).hasMatch(source.name)) {
            micSourceName = source.name;
            break;
          }
        }
        if (micSourceName != null) break;
      }
    }

    // Try to find mapped source for music channel
    String? musicSourceName = _musicConfig.mappedSourceName;
    if (musicSourceName == null) {
      // Auto-detect
      for (final source in sources) {
        for (final pattern in _musicConfig.sourcePatterns) {
          if (RegExp(pattern).hasMatch(source.name)) {
            musicSourceName = source.name;
            break;
          }
        }
        if (musicSourceName != null) break;
      }
    }
    
    // Build mic channel state
    final micSource = micSourceName != null 
        ? sources.where((s) => s.name == micSourceName).firstOrNull
        : null;
    if (micSource != null) {
      channels.add(AudioChannelState(
        type: AudioChannelType.microphone,
        name: _micConfig.name,
        sourceName: micSource.name,
        sourceFound: true,
        volumeMul: micSource.volumeMul,
        volumeDb: micSource.volumeDb,
        muted: micSource.muted,
        audioBalance: micSource.audioBalance,
        audioSyncOffset: micSource.audioSyncOffset,
        audioMonitorType: micSource.audioMonitorType,
        audioTracks: micSource.audioTracks,
      ));
    } else {
      channels.add(AudioChannelState.empty(_micConfig));
    }
    
    // Build music channel state
    final musicSource = musicSourceName != null 
        ? sources.where((s) => s.name == musicSourceName).firstOrNull
        : null;
    if (musicSource != null) {
      channels.add(AudioChannelState(
        type: AudioChannelType.musicDesktop,
        name: _musicConfig.name,
        sourceName: musicSource.name,
        sourceFound: true,
        volumeMul: musicSource.volumeMul,
        volumeDb: musicSource.volumeDb,
        muted: musicSource.muted,
        audioBalance: musicSource.audioBalance,
        audioSyncOffset: musicSource.audioSyncOffset,
        audioMonitorType: musicSource.audioMonitorType,
        audioTracks: musicSource.audioTracks,
      ));
    } else {
      channels.add(AudioChannelState.empty(_musicConfig));
    }
    
    return channels;
  }

  /// Get audio channel state by type
  AudioChannelState? getAudioChannel(AudioChannelType type) {
    try {
      return _state.audioChannels.firstWhere((c) => c.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Set mapped source for a channel (manual override)
  Future<bool> setAudioChannelSource(AudioChannelType type, String sourceName) async {
    if (type == AudioChannelType.microphone) {
      _micConfig = _micConfig.copyWith(mappedSourceName: sourceName);
      await _saveChannelConfigs();
    } else {
      _musicConfig = _musicConfig.copyWith(mappedSourceName: sourceName);
      await _saveChannelConfigs();
    }
    await _refresh();
    return true;
  }

  /// Clear mapped source for a channel (back to auto-detect)
  Future<bool> clearAudioChannelSource(AudioChannelType type) async {
    if (type == AudioChannelType.microphone) {
      _micConfig = _micConfig.copyWith(mappedSourceName: null);
      await _saveChannelConfigs();
    } else {
      _musicConfig = _musicConfig.copyWith(mappedSourceName: null);
      await _saveChannelConfigs();
    }
    await _refresh();
    return true;
  }

  // ── Audio Channel Actions (for agent) ──

  /// Get volume for a logical channel
  Future<({double? mul, double? db})?> getAudioChannelVolume(AudioChannelType type) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound) return null;
    return (mul: channel.volumeMul, db: channel.volumeDb);
  }

  /// Set volume for a logical channel (0.0 to ~20.0 multiplier)
  Future<bool> setAudioChannelVolume(AudioChannelType type, double volumeMul) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound || channel.sourceName == null) return false;
    try {
      await _obs!.inputs.setInputVolume(inputName: channel.sourceName!, inputVolume: volumeMul);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get mute state for a logical channel
  Future<bool?> getAudioChannelMute(AudioChannelType type) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound) return null;
    return channel.muted;
  }

  /// Set mute state for a logical channel
  Future<bool> setAudioChannelMute(AudioChannelType type, bool muted) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound || channel.sourceName == null) return false;
    try {
      await _obs!.inputs.setInputMute(inputName: channel.sourceName!, inputMuted: muted);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle mute for a logical channel
  Future<bool> toggleAudioChannelMute(AudioChannelType type) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound || channel.sourceName == null) return false;
    try {
      final result = await _obs!.inputs.toggleInputMute(inputName: channel.sourceName!);
      await _refresh();
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Get audio monitor type for a logical channel (0=off, 1=monitor only, 2=monitor and output)
  Future<int?> getAudioChannelMonitorType(AudioChannelType type) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound) return null;
    return channel.audioMonitorType;
  }

  /// Set audio monitor type for a logical channel
  Future<bool> setAudioChannelMonitorType(AudioChannelType type, int monitorType) async {
    final channel = getAudioChannel(type);
    if (channel == null || !channel.sourceFound || channel.sourceName == null) return false;
    try {
      final obsType = obs.ObsMonitoringType.values[monitorType.clamp(0, obs.ObsMonitoringType.values.length - 1)];
      await _obs!.inputs.setInputAudioMonitorType(inputName: channel.sourceName!, monitorType: obsType);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Audio Actions ──

  /// Get volume for a source
  Future<({double? mul, double? db})?> getSourceVolume(String sourceName) async {
    try {
      final resp = await _obs!.inputs.getInputVolume(inputName: sourceName);
      return (mul: resp.inputVolumeMul, db: resp.inputVolumeDb);
    } catch (_) {
      return null;
    }
  }

  /// Set volume for a source (0.0 to ~20.0 multiplier)
  Future<bool> setSourceVolume(String sourceName, double volumeMul) async {
    try {
      await _obs!.inputs.setInputVolume(inputName: sourceName, inputVolume: volumeMul);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get mute state for a source
  Future<bool?> getSourceMute(String sourceName) async {
    try {
      return await _obs!.inputs.getInputMute(sourceName);
    } catch (_) {
      return null;
    }
  }

  /// Set mute state for a source
  Future<bool> setSourceMute(String sourceName, bool muted) async {
    try {
      await _obs!.inputs.setInputMute(inputName: sourceName, inputMuted: muted);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle mute for a source
  Future<bool> toggleSourceMute(String sourceName) async {
    try {
      final result = await _obs!.inputs.toggleInputMute(inputName: sourceName);
      await _refresh();
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Get audio balance for a source (-1.0 left to 1.0 right)
  Future<double?> getSourceAudioBalance(String sourceName) async {
    try {
      final resp = await _obs!.inputs.getInputAudioBalance(inputName: sourceName);
      return resp.inputAudioBalance;
    } catch (_) {
      return null;
    }
  }

  /// Set audio balance for a source (-1.0 left to 1.0 right)
  Future<bool> setSourceAudioBalance(String sourceName, double balance) async {
    try {
      await _obs!.inputs.setInputAudioBalance(inputName: sourceName, inputAudioBalance: balance);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get audio sync offset in ms
  Future<int?> getSourceAudioSyncOffset(String sourceName) async {
    try {
      final resp = await _obs!.inputs.getInputAudioSyncOffset(inputName: sourceName);
      return resp.inputAudioSyncOffset;
    } catch (_) {
      return null;
    }
  }

  /// Set audio sync offset in ms
  Future<bool> setSourceAudioSyncOffset(String sourceName, int offsetMs) async {
    try {
      await _obs!.inputs.setInputAudioSyncOffset(inputName: sourceName, inputAudioSyncOffset: offsetMs);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get audio monitor type (0=off, 1=monitor only, 2=monitor and output)
  Future<int?> getSourceAudioMonitorType(String sourceName) async {
    try {
      final resp = await _obs!.inputs.getInputAudioMonitorType(inputName: sourceName);
      return resp.monitorType.index;
    } catch (_) {
      return null;
    }
  }

  /// Set audio monitor type (0=off, 1=monitor only, 2=monitor and output)
  Future<bool> setSourceAudioMonitorType(String sourceName, int monitorType) async {
    try {
      final type = obs.ObsMonitoringType.values[monitorType.clamp(0, obs.ObsMonitoringType.values.length - 1)];
      await _obs!.inputs.setInputAudioMonitorType(inputName: sourceName, monitorType: type);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Actions ──

  Future<bool> switchScene(String name) async {
    try {
      await _obs?.scenes.setCurrentProgramScene(name);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleSource(String sourceName) async {
    try {
      final scene = _state.currentScene;
      if (scene == null) return false;
      final items = await _obs!.sceneItems.getSceneItemList(scene);
      for (final item in items) {
        if (item.sourceName == sourceName) {
          await _obs!.sceneItems.setSceneItemEnabled(
            obs_event.SceneItemEnableStateChanged(
              sceneName: scene,
              sceneItemId: item.sceneItemId,
              sceneItemEnabled: !item.sceneItemEnabled,
            ),
          );
          await _refresh();
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setSourceEnabled(String sourceName, bool enabled) async {
    try {
      final scene = _state.currentScene;
      if (scene == null) return false;
      final items = await _obs!.sceneItems.getSceneItemList(scene);
      for (final item in items) {
        if (item.sourceName == sourceName) {
          await _obs!.sceneItems.setSceneItemEnabled(
            obs_event.SceneItemEnableStateChanged(
              sceneName: scene,
              sceneItemId: item.sceneItemId,
              sceneItemEnabled: enabled,
            ),
          );
          await _refresh();
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleStream() async {
    try {
      if (_state.streaming) {
        await _obs!.stream.stopStream();
      } else {
        await _obs!.stream.startStream();
      }
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleRecording() async {
    try {
      if (_state.recording) {
        await _obs!.record.stopRecord();
      } else {
        await _obs!.record.startRecord();
      }
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _obs?.close();
    super.dispose();
  }
}
