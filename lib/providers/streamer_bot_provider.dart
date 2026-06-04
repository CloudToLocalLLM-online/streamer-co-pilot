import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sse_client.dart';

/// Central state for the bot connection, stream status, chat, and errors.
class StreamerBotProvider extends ChangeNotifier {
  String _botUrl = 'http://localhost:8510';
  String get botUrl => _botUrl;
  SharedPreferences? _prefs;
  bool _prefsReady = false;
  String? _pendingUrl;

  StreamerBotProvider() {
    _initPrefs();
  }

  // ── Persistence ──

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _prefsReady = true;
    final saved = _prefs!.getString('botUrl');
    if (saved != null && saved.isNotEmpty) {
      _botUrl = saved;
      notifyListeners();
    }
    if (_pendingUrl != null) {
      _prefs!.setString('botUrl', _pendingUrl!);
      _pendingUrl = null;
    }
  }

  void setBotUrl(String url) {
    _botUrl = url;
    if (_prefsReady && _prefs != null) {
      _prefs!.setString('botUrl', url);
    } else {
      _pendingUrl = url;
    }
    notifyListeners();
  }

  // ── Stream status ──

  String _streamStatus = 'unknown';
  String get streamStatus => _streamStatus;
  int _viewers = 0;
  int get viewers => _viewers;
  String _game = '';
  String get game => _game;
  String _title = '';
  String get title => _title;

  // ── Errors ──

  String? _lastError;
  String? get lastError => _lastError;
  Timer? _errorPoller;

  void _setError(String context, dynamic error) {
    final msg = '[$context] $error';
    debugPrint('[provider] ERROR: $msg');
    _lastError = msg;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Future<void> fetchBackendErrors() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/errors'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          for (final err in errors) {
            if (err is Map && err['context'] != null) {
              _setError('backend/${err['context']}', err['message'] ?? err['type']);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _startErrorPoller() {
    _errorPoller?.cancel();
    _errorPoller = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchBackendErrors();
    });
    fetchBackendErrors();
  }

  // ── Chat & connection state ──

  List<Map<String, dynamic>> _chat = [];
  List<Map<String, dynamic>> get chat => _chat;
  bool _connected = false;
  bool get connected => _connected;

  SseClient? _sse;
  StreamSubscription<String>? _sseSub;
  Timer? _reconnectTimer;
  Process? _serviceProcess;

  // ── Exponential backoff state ──
  int _reconnectAttempt = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);

  // ── API calls ──

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/health'))
          .timeout(const Duration(seconds: 3));
      _connected = res.statusCode == 200;
      notifyListeners();
      return _connected;
    } catch (e) {
      _setError('checkHealth', e);
      _connected = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _launchService() async {
    final pythonBin = await _resolvePython();
    if (pythonBin == null) return false;
    return _tryLaunch(pythonBin);
  }

  Future<String?> _resolvePython() async {
    final envPython = Platform.environment['STREAMER_COPILOT_PYTHON'];
    if (envPython != null && envPython.isNotEmpty && await File(envPython).exists()) {
      return envPython;
    }
    final appPath = Platform.resolvedExecutable;
    for (var dir = File(appPath).parent; dir.path != '/'; dir = dir.parent) {
      final candidate = '${dir.path}/streamer-co-pilot-service/.venv/bin/python3';
      if (await File(candidate).exists()) return candidate;
    }
    final home = Platform.environment['HOME'] ?? '';
    final fallbacks = [
      if (home.isNotEmpty) '$home/streamer-co-pilot-service/.venv/bin/python3',
      '/opt/streamer-co-pilot-service/.venv/bin/python3',
    ];
    for (final path in fallbacks) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<bool> _tryLaunch(String pythonBin) async {
    final serviceDir = '${Directory(pythonBin).parent.parent.path}/services/bot-service';
    if (!await Directory(serviceDir).exists()) return false;
    try {
      _serviceProcess = await Process.start(
        pythonBin,
        ['api.py'],
        workingDirectory: serviceDir,
        environment: {'TWITCH_BOT_PORT': '8510'},
      );
      _serviceProcess?.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('[bot] $line'));
      return true;
    } catch (e) {
      _setError('launchService', e);
      return false;
    }
  }

  Future<bool> connectSse() async {
    _reconnectAttempt = 0;
    var ok = await checkHealth();
    if (!ok) {
      ok = await _launchService();
      if (ok) {
        await Future.delayed(const Duration(seconds: 3));
        ok = await checkHealth();
      }
    }
    if (!ok) return false;

    _sse?.disconnect();
    await _sseSub?.cancel();

    _sse = SseClient(_botUrl);
    try {
      _sseSub = _sse!.connect().listen(_handleSseEvent,
          onError: (e) {
            _setError('sseStream', e);
            _scheduleReconnect();
          },
          onDone: () => _scheduleReconnect());
    } catch (e) {
      _setError('connectSse', e);
      _scheduleReconnect();
      return false;
    }

    fetchStatus();
    fetchChat();
    _startErrorPoller();
    _connected = true;
    notifyListeners();
    return true;
  }

  void _handleSseEvent(String raw) {
    final parts = raw.split('\x00');
    if (parts.length == 2 && parts[0] == 'status') {
      try {
        final data = jsonDecode(parts[1]);
        _streamStatus = data['status'] ?? _streamStatus;
        _title = data['title'] ?? _title;
        _game = data['game'] ?? _game;
        _viewers = data['viewers'] ?? _viewers;
        notifyListeners();
      } catch (e) {
        _setError('handleSseEvent/status', e);
      }
    } else {
      try {
        final msg = jsonDecode(raw);
        _chat.insert(0, Map<String, dynamic>.from(msg));
        if (_chat.length > 200) _chat = _chat.sublist(0, 200);
        notifyListeners();
      } catch (e) {
        _setError('handleSseEvent/chat', e);
      }
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    notifyListeners();
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final delay = Duration(
      seconds: _reconnectAttempt > 10
          ? _maxReconnectDelay.inSeconds
          : (5 * _reconnectAttempt).clamp(5, _maxReconnectDelay.inSeconds),
    );
    debugPrint('[provider] reconnect attempt $_reconnectAttempt in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () {
      connectSse();
    });
  }

  void disconnect() {
    _errorPoller?.cancel();
    _errorPoller = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _sseSub?.cancel();
    _sseSub = null;
    _sse?.disconnect();
    _sse = null;
    _connected = false;
    notifyListeners();
  }

  Future<void> fetchStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/stream/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _streamStatus = data['status'] ?? 'unknown';
        _viewers = data['viewers'] ?? 0;
        _game = data['game'] ?? '';
        _title = data['title'] ?? '';
        notifyListeners();
      }
    } catch (e) {
      _setError('fetchStatus', e);
    }
  }

  Future<void> fetchChat() async {
    try {
      final res = await http
          .get(Uri.parse('$_botUrl/chat/recent?count=30'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _chat = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        notifyListeners();
      }
    } catch (e) {
      _setError('fetchChat', e);
    }
  }

  Future<bool> sendMessage(String text) async {
    try {
      final res = await http
          .post(Uri.parse('$_botUrl/chat/send'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'message': text}))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (e) {
      _setError('sendMessage', e);
      return false;
    }
  }

  @override
  void dispose() {
    _serviceProcess?.kill();
    disconnect();
    super.dispose();
  }
}