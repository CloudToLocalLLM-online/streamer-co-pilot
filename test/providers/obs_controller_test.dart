import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_co_pilot/providers/obs_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ObsController - basic state', () {
    late ObsController controller;

    setUp(() {
      controller = ObsController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has connected=false and empty collections', () {
      expect(controller.state.connected, false);
      expect(controller.state.currentScene, isNull);
      expect(controller.state.scenes, isEmpty);
      expect(controller.state.sources, isEmpty);
      expect(controller.state.streaming, false);
      expect(controller.state.recording, false);
      expect(controller.state.streamDurationSec, isNull);
      expect(controller.state.audioChannels, isEmpty);
    });

    test('configure updates host/port/password (state unchanged until connect)', () {
      controller.configure(host: '192.168.1.10', port: 4456, password: 'secret');
      expect(controller.state.connected, false);
    });

    test('disconnect resets state to defaults', () {
      controller.disconnect();
      expect(controller.state.connected, false);
      expect(controller.state.currentScene, isNull);
      expect(controller.state.scenes, isEmpty);
      expect(controller.state.sources, isEmpty);
      expect(controller.state.streaming, false);
      expect(controller.state.recording, false);
    });
  });

  group('ObsController - audio channel config', () {
    late ObsController controller;

    setUp(() {
      controller = ObsController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('updateMicConfig notifies listeners and updates config', () {
      bool notified = false;
      controller.addListener(() => notified = true);

      final config = AudioChannelConfig(
        type: AudioChannelType.microphone,
        name: 'Custom Mic',
        sourcePatterns: [r'custom.*mic'],
        mappedSourceName: 'My Mic',
      );
      controller.updateMicConfig(config);

      expect(notified, true);
      expect(controller.micConfig.name, 'Custom Mic');
      expect(controller.micConfig.mappedSourceName, 'My Mic');
      expect(controller.micConfig.sourcePatterns, [r'custom.*mic']);
    });

    test('updateMusicConfig notifies listeners and updates config', () {
      bool notified = false;
      controller.addListener(() => notified = true);

      final config = AudioChannelConfig(
        type: AudioChannelType.musicDesktop,
        name: 'Custom Music',
        sourcePatterns: [r'custom.*music'],
        mappedSourceName: 'My Music',
      );
      controller.updateMusicConfig(config);

      expect(notified, true);
      expect(controller.musicConfig.name, 'Custom Music');
      expect(controller.musicConfig.mappedSourceName, 'My Music');
      expect(controller.musicConfig.sourcePatterns, [r'custom.*music']);
    });

    test('clearAudioChannelSource removes mapped source for mic', () async {
      controller.updateMicConfig(AudioChannelConfig(
        type: AudioChannelType.microphone,
        name: 'Mic',
        sourcePatterns: [],
        mappedSourceName: 'Old Mic',
      ));
      expect(controller.micConfig.mappedSourceName, 'Old Mic');

      await controller.clearAudioChannelSource(AudioChannelType.microphone);
      expect(controller.micConfig.mappedSourceName, isNull);
    });

    test('clearAudioChannelSource removes mapped source for music', () async {
      controller.updateMusicConfig(AudioChannelConfig(
        type: AudioChannelType.musicDesktop,
        name: 'Music',
        sourcePatterns: [],
        mappedSourceName: 'Old Music',
      ));
      expect(controller.musicConfig.mappedSourceName, 'Old Music');

      await controller.clearAudioChannelSource(AudioChannelType.musicDesktop);
      expect(controller.musicConfig.mappedSourceName, isNull);
    });

    test('setAudioChannelSource updates mapped source for mic', () async {
      await controller.setAudioChannelSource(AudioChannelType.microphone, 'New Mic Source');
      expect(controller.micConfig.mappedSourceName, 'New Mic Source');
    });

    test('setAudioChannelSource updates mapped source for music', () async {
      await controller.setAudioChannelSource(AudioChannelType.musicDesktop, 'New Music Source');
      expect(controller.musicConfig.mappedSourceName, 'New Music Source');
    });

    test('getAudioChannel returns null when not connected', () {
      expect(controller.getAudioChannel(AudioChannelType.microphone), isNull);
      expect(controller.getAudioChannel(AudioChannelType.musicDesktop), isNull);
    });
  });

  group('ObsController - actions return false when not connected', () {
    late ObsController controller;

    setUp(() {
      controller = ObsController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('switchScene returns false when not connected', () async {
      expect(await controller.switchScene('Any Scene'), false);
    });

    test('toggleSource returns false when not connected', () async {
      expect(await controller.toggleSource('Any Source'), false);
    });

    test('setSourceEnabled returns false when not connected', () async {
      expect(await controller.setSourceEnabled('Any Source', true), false);
    });

    test('toggleStream returns false when not connected', () async {
      expect(await controller.toggleStream(), false);
    });

    test('toggleRecording returns false when not connected', () async {
      expect(await controller.toggleRecording(), false);
    });
  });

  group('ObsController - audio channel actions return false/null when not connected', () {
    late ObsController controller;

    setUp(() {
      controller = ObsController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('getAudioChannelVolume returns null when not connected', () async {
      expect(await controller.getAudioChannelVolume(AudioChannelType.microphone), isNull);
      expect(await controller.getAudioChannelVolume(AudioChannelType.musicDesktop), isNull);
    });

    test('setAudioChannelVolume returns false when not connected', () async {
      expect(await controller.setAudioChannelVolume(AudioChannelType.microphone, 1.0), false);
      expect(await controller.setAudioChannelVolume(AudioChannelType.musicDesktop, 1.0), false);
    });

    test('getAudioChannelMute returns null when not connected', () async {
      expect(await controller.getAudioChannelMute(AudioChannelType.microphone), isNull);
      expect(await controller.getAudioChannelMute(AudioChannelType.musicDesktop), isNull);
    });

    test('setAudioChannelMute returns false when not connected', () async {
      expect(await controller.setAudioChannelMute(AudioChannelType.microphone, true), false);
      expect(await controller.setAudioChannelMute(AudioChannelType.musicDesktop, true), false);
    });

    test('toggleAudioChannelMute returns false when not connected', () async {
      expect(await controller.toggleAudioChannelMute(AudioChannelType.microphone), false);
      expect(await controller.toggleAudioChannelMute(AudioChannelType.musicDesktop), false);
    });

    test('getAudioChannelMonitorType returns null when not connected', () async {
      expect(await controller.getAudioChannelMonitorType(AudioChannelType.microphone), isNull);
      expect(await controller.getAudioChannelMonitorType(AudioChannelType.musicDesktop), isNull);
    });

    test('setAudioChannelMonitorType returns false when not connected', () async {
      expect(await controller.setAudioChannelMonitorType(AudioChannelType.microphone, 1), false);
      expect(await controller.setAudioChannelMonitorType(AudioChannelType.musicDesktop, 1), false);
    });
  });

  group('ObsController - source audio actions return false/null when not connected', () {
    late ObsController controller;

    setUp(() {
      controller = ObsController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('getSourceVolume returns null when not connected', () async {
      expect(await controller.getSourceVolume('Any Source'), isNull);
    });

    test('setSourceVolume returns false when not connected', () async {
      expect(await controller.setSourceVolume('Any Source', 1.0), false);
    });

    test('getSourceMute returns null when not connected', () async {
      expect(await controller.getSourceMute('Any Source'), isNull);
    });

    test('setSourceMute returns false when not connected', () async {
      expect(await controller.setSourceMute('Any Source', true), false);
    });

    test('toggleSourceMute returns false when not connected', () async {
      expect(await controller.toggleSourceMute('Any Source'), false);
    });

    test('getSourceAudioBalance returns null when not connected', () async {
      expect(await controller.getSourceAudioBalance('Any Source'), isNull);
    });

    test('setSourceAudioBalance returns false when not connected', () async {
      expect(await controller.setSourceAudioBalance('Any Source', 0.0), false);
    });

    test('getSourceAudioSyncOffset returns null when not connected', () async {
      expect(await controller.getSourceAudioSyncOffset('Any Source'), isNull);
    });

    test('setSourceAudioSyncOffset returns false when not connected', () async {
      expect(await controller.setSourceAudioSyncOffset('Any Source', 0), false);
    });

    test('getSourceAudioMonitorType returns null when not connected', () async {
      expect(await controller.getSourceAudioMonitorType('Any Source'), isNull);
    });

    test('setSourceAudioMonitorType returns false when not connected', () async {
      expect(await controller.setSourceAudioMonitorType('Any Source', 1), false);
    });
  });

  group('ObsController - data classes', () {
    test('ObsState default constructor', () {
      const state = ObsState();
      expect(state.connected, false);
      expect(state.currentScene, isNull);
      expect(state.scenes, isEmpty);
      expect(state.sources, isEmpty);
      expect(state.streaming, false);
      expect(state.recording, false);
      expect(state.streamDurationSec, isNull);
      expect(state.audioChannels, isEmpty);
    });

    test('ObsState named constructor with all fields', () {
      const state = ObsState(
        connected: true,
        currentScene: 'Game',
        scenes: ['Game', 'BRB'],
        streaming: true,
        recording: false,
        streamDurationSec: 3600,
      );
      expect(state.connected, true);
      expect(state.currentScene, 'Game');
      expect(state.scenes, ['Game', 'BRB']);
      expect(state.streaming, true);
      expect(state.recording, false);
      expect(state.streamDurationSec, 3600);
    });

    test('ObsSourceState constructor', () {
      const source = ObsSourceState(
        name: 'Webcam',
        enabled: true,
        itemId: 42,
        volumeMul: 1.5,
        volumeDb: 3.5,
        muted: false,
      );
      expect(source.name, 'Webcam');
      expect(source.enabled, true);
      expect(source.itemId, 42);
      expect(source.volumeMul, 1.5);
      expect(source.volumeDb, 3.5);
      expect(source.muted, false);
    });

    test('AudioChannelConfig default values and copyWith', () {
      const mic = AudioChannelConfig.defaultMic;
      expect(mic.type, AudioChannelType.microphone);
      expect(mic.name, 'Microphone');
      expect(mic.sourcePatterns, isNotEmpty);

      final copied = mic.copyWith(mappedSourceName: 'New Mic');
      expect(copied.mappedSourceName, 'New Mic');
      expect(copied.name, mic.name);
      expect(copied.sourcePatterns, mic.sourcePatterns);
    });

    test('AudioChannelConfig copyWith clears mappedSourceName when null passed', () {
      final mic = AudioChannelConfig.defaultMic.copyWith(mappedSourceName: 'Some Mic');
      expect(mic.mappedSourceName, 'Some Mic');

      final cleared = mic.copyWith(mappedSourceName: null);
      expect(cleared.mappedSourceName, isNull);
    });

    test('AudioChannelConfig.defaultMusic values', () {
      const music = AudioChannelConfig.defaultMusic;
      expect(music.type, AudioChannelType.musicDesktop);
      expect(music.name, 'Music/Desktop');
      expect(music.sourcePatterns, isNotEmpty);
    });

    test('AudioChannelState empty factory', () {
      const config = AudioChannelConfig.defaultMic;
      final empty = AudioChannelState.empty(config);
      expect(empty.type, AudioChannelType.microphone);
      expect(empty.name, 'Microphone');
      expect(empty.sourceFound, false);
      expect(empty.sourceName, isNull);
    });

    test('AudioChannelState constructor with all fields', () {
      const state = AudioChannelState(
        type: AudioChannelType.microphone,
        name: 'Test Mic',
        sourceName: 'Mic Source',
        sourceFound: true,
        volumeMul: 1.2,
        volumeDb: 2.0,
        muted: true,
        audioBalance: 0.1,
        audioSyncOffset: 100,
        audioMonitorType: 2,
        audioTracks: 1,
      );
      expect(state.type, AudioChannelType.microphone);
      expect(state.name, 'Test Mic');
      expect(state.sourceName, 'Mic Source');
      expect(state.sourceFound, true);
      expect(state.volumeMul, 1.2);
      expect(state.volumeDb, 2.0);
      expect(state.muted, true);
      expect(state.audioBalance, 0.1);
      expect(state.audioSyncOffset, 100);
      expect(state.audioMonitorType, 2);
      expect(state.audioTracks, 1);
    });
  });

  group('ObsController - connect() behavior contract', () {
    test('connect() returns false when no OBS server available', () async {
      final controller = ObsController();
      final result = await controller.connect();
      expect(result, false);
      expect(controller.state.connected, false);
      controller.dispose();
    });

    test('disconnect() is idempotent', () async {
      final controller = ObsController();
      controller.disconnect();
      controller.disconnect(); // second call should not throw
      expect(controller.state.connected, false);
      controller.dispose();
    });
  });

  group('ObsController - configuration persistence round-trip', () {
    test('configure values can be set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final controller = ObsController();
      controller.configure(host: 'obs.local', port: 5555, password: 'mypass');
      controller.dispose();
    });
  });
}