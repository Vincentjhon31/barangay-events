import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:eCalendar/event_store.dart';
import 'package:eCalendar/offline_cache.dart';
import 'package:eCalendar/offline_store_io.dart';

/// A stand-in for a Supabase `.stream()`: each try is a new controller the
/// test feeds rows or an error into.
class FakeLive {
  final List<StreamController<List<Map<String, dynamic>>>> tries = [];

  Stream<List<Map<String, dynamic>>> call() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    tries.add(controller);
    return controller.stream;
  }

  StreamController<List<Map<String, dynamic>>> get current => tries.last;
}

class NetworkDown implements Exception {}

class DatabaseAnswer implements Exception {}

Map<String, dynamic> row(String id, String title, {String start = '2026-11-07T10:00:00+00:00'}) => {
      'id': id,
      'title': title,
      'location': 'Municipal Plaza',
      'start_time': start,
      'end_time': '2026-11-07T12:00:00+00:00',
      'day_key': '2026-11-07T00:00:00+00:00',
      'description': '',
      'created_at': '2026-11-01T09:30:00+00:00',
      'event_type': 'public',
      'daily_overrides': [
        {'day': '2026-11-07T00:00:00.000Z', 'start_minutes': 600, 'end_minutes': 720},
      ],
    };

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late OfflineCache cache;
  late MemoryOfflineStore store;
  late FakeLive live;
  late Map<String, SavedRows> latest;
  late List<EventSyncStatus> statuses;

  setUp(() {
    store = MemoryOfflineStore();
    cache = OfflineCache(store);
    live = FakeLive();
    latest = {};
    statuses = [];
  });

  Stream<List<BarangayEvent>> events({String name = 'events-u1', Duration retry = const Duration(milliseconds: 30)}) =>
      liveWithOfflineCopy(
        cache: cache,
        name: name,
        live: live.call,
        convert: (rows) => rows.map(BarangayEvent.fromSupabase).toList(),
        latest: latest,
        isConnectionError: (error) => error is! DatabaseAnswer,
        onStatus: statuses.add,
        retryDelay: (_) => retry,
      );

  test('saved rows come back exactly, and clear removes them', () async {
    final saved = SavedRows(DateTime(2026, 11, 6, 14, 41), [row('a', 'Foundation Day')]);
    await cache.writeRows('events-u1', saved);
    final back = await cache.readRows('events-u1');
    expect(back!.savedAt, saved.savedAt);
    expect(back.rows.single['title'], 'Foundation Day');
    expect(back.rows.single['daily_overrides'], isA<List>());
    await cache.clear();
    expect(await cache.readRows('events-u1'), isNull);
  });

  test('a damaged saved copy is ignored instead of breaking the app', () async {
    store.data['events-u1'] = '{"saved_at": "2026-11-06T14:41:00.000", "rows": [';
    expect(await cache.readRows('events-u1'), isNull);
    store.data['events-u1'] = '{"rows": []}';
    expect(await cache.readRows('events-u1'), isNull);
  });

  test('each account (and guest) has its own saved copy', () {
    expect(offlineCacheName('events', 'u1'), 'events-u1');
    expect(offlineCacheName('events', 'u2'), isNot(offlineCacheName('events', 'u1')));
    expect(offlineCacheName('events', null), 'events-guest');
  });

  test('online: live events are shown and saved for next time', () async {
    final seen = <List<BarangayEvent>>[];
    final sub = events().listen(seen.add);
    await settle();
    live.current.add([row('a', 'Foundation Day')]);
    await settle();

    expect(seen.single.single.title, 'Foundation Day');
    expect(statuses.last.offline, isFalse);
    final saved = await cache.readRows('events-u1');
    expect(saved!.rows.single['id'], 'a');
    await sub.cancel();
  });

  test('offline: the saved copy shows, with when it was saved, and the app keeps retrying', () async {
    final savedAt = DateTime(2026, 11, 6, 14, 41);
    await cache.writeRows('events-u1', SavedRows(savedAt, [row('a', 'Foundation Day')]));

    final seen = <List<BarangayEvent>>[];
    final sub = events().listen(seen.add);
    await settle();
    expect(seen.single.single.title, 'Foundation Day', reason: 'saved copy shown at once');

    live.current.addError(NetworkDown());
    await settle();
    expect(statuses.last.offline, isTrue);
    expect(statuses.last.savedAt, savedAt);

    // The retry is a fresh live stream; when the connection is back it wins.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(live.tries.length, greaterThanOrEqualTo(2));
    live.current.add([row('a', 'Foundation Day'), row('b', 'Liga opening')]);
    await settle();
    expect(seen.last.map((e) => e.title), ['Foundation Day', 'Liga opening']);
    expect(statuses.last.offline, isFalse);
    await sub.cancel();
  });

  test('offline with nothing saved yet: no events, and the bar says so', () async {
    final seen = <List<BarangayEvent>>[];
    final sub = events().listen(seen.add);
    await settle();
    live.current.addError(NetworkDown());
    await settle();
    expect(seen, isEmpty, reason: 'never an empty list that looks like "no events"');
    expect(statuses.last.offline, isTrue);
    expect(statuses.last.savedAt, isNull);
    await sub.cancel();
  });

  test('a database error is not "offline" (and is still retried quietly)', () async {
    final sub = events().listen((_) {});
    await settle();
    live.current.addError(DatabaseAnswer());
    await settle();
    expect(statuses.where((s) => s.offline), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(live.tries.length, greaterThanOrEqualTo(2));
    await sub.cancel();
  });

  test('if the server answers before the saved copy is read, the old copy is never shown', () async {
    store.data['events-u1'] = '{"saved_at": "2026-11-01T08:00:00.000", "rows": []}';
    final slowStore = _SlowStore(store);
    cache = OfflineCache(slowStore);
    final seen = <List<BarangayEvent>>[];
    final sub = events().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    live.current.add([row('a', 'Fresh')]);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(seen.length, 1);
    expect(seen.single.single.title, 'Fresh');
    await sub.cancel();
  });

  test('a second listener (pull to refresh, a day page) gets the latest rows at once', () async {
    final first = events().listen((_) {});
    await settle();
    live.current.add([row('a', 'Foundation Day')]);
    await settle();

    final seen = <List<BarangayEvent>>[];
    final second = events().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(seen.single.single.title, 'Foundation Day');
    await first.cancel();
    await second.cancel();
  });

  test('cancelling stops the retries', () async {
    final sub = events().listen((_) {});
    await settle();
    live.current.addError(NetworkDown());
    await settle();
    await sub.cancel();
    final tries = live.tries.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(live.tries.length, tries);
  });

  test('retry waits grow from 5 seconds to at most a minute', () {
    expect([for (var i = 0; i < 7; i++) offlineRetryDelay(i).inSeconds], [5, 10, 20, 40, 60, 60, 60]);
  });

  test('the file store writes, reads back, survives a half-written temp file, and clears', () async {
    final dir = await Directory.systemTemp.createTemp('offline-store-test-');
    addTearDown(() => dir.delete(recursive: true));
    final files = FileOfflineStore(directory: () async => Directory('${dir.path}/offline'));
    final fileCache = OfflineCache(files);

    await fileCache.writeRows('events-u1', SavedRows(DateTime(2026, 11, 6), [row('a', 'Foundation Day')]));
    await fileCache.writeRows('events-u1', SavedRows(DateTime(2026, 11, 6), [row('a', 'Foundation Day'), row('b', 'Liga')]));
    expect((await fileCache.readRows('events-u1'))!.rows.length, 2);

    // A crash mid-write leaves only the temp file; the real copy is intact.
    await File('${dir.path}/offline/events-u1.json.tmp').writeAsString('{"saved_at": "x", "ro');
    expect((await fileCache.readRows('events-u1'))!.rows.length, 2);

    await fileCache.clear();
    expect(await fileCache.readRows('events-u1'), isNull);
    expect(Directory('${dir.path}/offline').listSync(), isEmpty);
  });
}

/// Reads slowly, to let the server answer first.
class _SlowStore implements OfflineStore {
  _SlowStore(this.inner);

  final OfflineStore inner;

  @override
  Future<String?> read(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return inner.read(name);
  }

  @override
  Future<void> write(String name, String data) => inner.write(name, data);

  @override
  Future<void> clear() => inner.clear();
}
