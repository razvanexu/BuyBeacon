import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Best-effort append-only file logger for on-device debugging sessions where
/// no live adb connection is available (e.g. walking outside Wi-Fi range).
/// Writes to the app's external files dir (NOT internal /data/data storage --
/// that requires root or a debuggable build to `adb pull`, and release builds
/// aren't debuggable). Pull the file afterwards with:
///   adb pull /storage/emulated/0/Android/data/com.buy_beacon.frontend/files/buybeacon_debug_log.txt
/// (exact package id: see applicationId in android/app/build.gradle.kts)
class DebugFileLogger {
  static final DebugFileLogger _instance = DebugFileLogger._internal();

  factory DebugFileLogger() => _instance;

  DebugFileLogger._internal();

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getExternalStorageDirectory();
    _file = File('${dir!.path}/buybeacon_debug_log.txt');
    return _file!;
  }

  Future<void> log(String message) async {
    final line = '${DateTime.now().toIso8601String()} $message\n';
    try {
      final file = await _getFile();
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Debug-only convenience; a logging failure must never affect app behavior.
    }
  }
}
