import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists which geofences the user was last confirmed inside, and when, so
/// [GeofenceService] can survive the app process being killed in the
/// background. Without it, every restart starts with an empty "inside" set and
/// re-fires ENTER (and a notification) for every shop the user is already
/// standing next to.
class GeofenceStateStore {
  static const String _fileName = 'geofence_state.json';

  Future<Map<String, DateTime>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return decoded.map(
        (identifier, millis) =>
            MapEntry(identifier, DateTime.fromMillisecondsSinceEpoch(millis as int)),
      );
    } catch (e) {
      log('[GeofenceStateStore] load failed: $e', name: 'GeofenceStateStore');
      return {};
    }
  }

  Future<void> save(Map<String, DateTime> lastInsideAt) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(
          lastInsideAt.map((id, time) => MapEntry(id, time.millisecondsSinceEpoch)),
        ),
      );
    } catch (e) {
      log('[GeofenceStateStore] save failed: $e', name: 'GeofenceStateStore');
    }
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }
}
