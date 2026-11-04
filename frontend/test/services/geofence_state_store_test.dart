import 'dart:io';

import 'package:buy_beacon/services/geofence_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late GeofenceStateStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('geofence_state_test');
    store = GeofenceStateStore(directory: () async => directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test('load returns nothing when no state was saved', () async {
    expect(await store.load(), isEmpty);
  });

  test('an ENTER burst of overlapping saves still loads back the final state', () async {
    final now = DateTime.fromMillisecondsSinceEpoch(1762236310000);
    final state = <String, DateTime>{};
    final saves = <Future<void>>[];
    for (var i = 0; i < 14; i++) {
      state['shop_$i'] = now;
      saves.add(store.save(state));
    }
    await Future.wait(saves);

    final loaded = await GeofenceStateStore(directory: () async => directory).load();

    expect(loaded, hasLength(14));
    expect(loaded['shop_13'], now);
  });

  test('a corrupt file loads as empty instead of throwing', () async {
    await File('${directory.path}/geofence_state.json').writeAsString('{"shop_1": 17');

    expect(await store.load(), isEmpty);
  });
}
