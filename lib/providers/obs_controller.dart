import 'dart:async';
import 'package:flutter/material.dart';
import 'package:obs_websocket/obs_websocket.dart' as obs;
import 'package:obs_websocket/event.dart' as obs_event;

/// State of a single OBS source (camera, mic, etc.)
class ObsSourceState {
  final String name;
  final bool enabled;
  final int itemId;

  const ObsSourceState({
    required this.name,
    required this.enabled,
    required this.itemId,
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

  const ObsState({
    this.connected = false,
    this.currentScene,
    this.scenes = const [],
    this.sources = const [],
    this.streaming = false,
    this.recording = false,
    this.streamDurationSec,
  });
}

/// Controls OBS Studio via obs-websocket.
class ObsController extends ChangeNotifier {
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

  // ── Connection ──

  Future<bool> connect() async {
    _reconnectTimer?.cancel();
    try {
      _obs = await obs.ObsWebSocket.connect(
        '$_host:$_port',
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
          sources.add(ObsSourceState(
            name: item.sourceName,
            enabled: item.sceneItemEnabled,
            itemId: item.sceneItemId,
          ));
        }
      } catch (_) {
        // Scene might be empty or not exist
      }

      _state = ObsState(
        connected: true,
        currentScene: currentScene,
        scenes: sceneList.scenes.map((s) => s.sceneName).toList(),
        sources: sources,
        streaming: streamStatus.outputActive,
        recording: recordStatus.outputActive,
        streamDurationSec: streamStatus.outputDuration ~/ 1000,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[ObsController] refresh error: $e');
      _state = ObsState(connected: false);
      notifyListeners();
      _scheduleReconnect();
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
