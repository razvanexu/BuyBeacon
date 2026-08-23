import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Best-effort append-only logger for on-device debugging sessions.
///
/// Writes to two places:
/// 1. The app's external files dir (NOT internal /data/data storage -- that
///    requires root or a debuggable build to `adb pull`, and release builds
///    aren't debuggable). Pull the file afterwards with:
///      adb pull /storage/emulated/0/Android/data/com.buy_beacon.frontend/files/buybeacon_debug_log.txt
///    (exact package id: see applicationId in android/app/build.gradle.kts)
/// 2. The backend's temporary /api/debug/log sink (see DebugLogController on
///    the backend), over the internet -- not just home Wi-Fi -- so entries
///    are visible near-real-time without waiting for an adb session. Best
///    effort: failures here are swallowed, the local file always still gets
///    written regardless of network availability.
///
/// TEMPORARY debug tooling for the location-tracking investigation (see
/// CLAUDE.md). Remove alongside DebugLogController once resolved.
class DebugFileLogger {
  static final DebugFileLogger _instance = DebugFileLogger._internal();

  factory DebugFileLogger() => _instance;

  DebugFileLogger._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.180:8080',
  );

  // Must match DEBUG_LOG_TOKEN configured server-side. Pass at build time:
  //   --dart-define=DEBUG_LOG_TOKEN=<token>
  // Left empty (remote logging silently disabled) if not provided.
  static const String _debugLogToken = String.fromEnvironment('DEBUG_LOG_TOKEN');

  File? _file;
  String? _deviceId;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getExternalStorageDirectory();
    _file = File('${dir!.path}/buybeacon_debug_log.txt');
    return _file!;
  }

  // Both the local file and the remote sink are shared across every install
  // that logs to them (e.g. two testers walking at once, or one tester
  // across multiple sideloaded builds) -- without a per-install tag, entries
  // from different phones interleave indistinguishably. Generated once per
  // install and persisted alongside the log file itself.
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    try {
      final dir = await getExternalStorageDirectory();
      final idFile = File('${dir!.path}/buybeacon_debug_device_id.txt');
      if (await idFile.exists()) {
        _deviceId = (await idFile.readAsString()).trim();
      } else {
        final id = List.generate(
          6,
          (_) => '0123456789abcdef'[Random().nextInt(16)],
        ).join();
        await idFile.writeAsString(id);
        _deviceId = id;
      }
    } catch (_) {
      _deviceId = 'unknown';
    }
    return _deviceId!;
  }

  Future<void> log(String message) async {
    final deviceId = await _getDeviceId();
    final line = '${DateTime.now().toIso8601String()} [$deviceId] $message\n';
    try {
      final file = await _getFile();
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Debug-only convenience; a logging failure must never affect app behavior.
    }
    unawaited(_postRemote('[$deviceId] $message'));
  }

  Future<void> _postRemote(String message) async {
    if (_debugLogToken.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/api/debug/log'),
            headers: {
              'Content-Type': 'application/json',
              'X-Debug-Token': _debugLogToken,
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort; local file write above is the source of truth.
    }
  }
}
