import 'dart:convert';
import 'dart:io';

import 'package:buy_beacon/utils/debug_file_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Persists which geofences the user was last confirmed inside, and when, so
/// [GeofenceService] can survive the app process being killed in the
/// background. Without it, every restart starts with an empty "inside" set and
/// re-fires ENTER (and a notification) for every shop the user is already
/// standing next to.
class GeofenceStateStore {
  static const String _fileName = 'geofence_state.json';

  final Future<Directory> Function() _directory;

  GeofenceStateStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  // Saves are chained so they never overlap: an ENTER burst triggers one save
  // per shop, and overlapping writes to the same file could leave it corrupt
  // -- which then silently restores nothing after a restart.
  Future<void> _pendingSave = Future.value();

  Future<Map<String, DateTime>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        DebugFileLogger().log('GeofenceStateStore.load no saved state');
        return {};
      }
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final state = decoded.map(
        (identifier, millis) =>
            MapEntry(identifier, DateTime.fromMillisecondsSinceEpoch(millis as int)),
      );
      DebugFileLogger().log('GeofenceStateStore.load ${state.length} entries');
      return state;
    } catch (e) {
      DebugFileLogger().log('GeofenceStateStore.load failed: $e');
      return {};
    }
  }

  Future<void> save(Map<String, DateTime> lastInsideAt) {
    final snapshot = Map.of(lastInsideAt);
    _pendingSave = _pendingSave.then((_) => _write(snapshot));
    return _pendingSave;
  }

  // Written to a temp file and renamed, so a process killed mid-write leaves
  // the previous complete file rather than a truncated one.
  Future<void> _write(Map<String, DateTime> lastInsideAt) async {
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode(
          lastInsideAt.map((id, time) => MapEntry(id, time.millisecondsSinceEpoch)),
        ),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (e) {
      DebugFileLogger().log('GeofenceStateStore.save failed: $e');
    }
  }

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}/$_fileName');
  }
}
