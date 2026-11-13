import 'dart:async';
import 'dart:convert';

import 'offline_store.dart';

/// Where [OfflineCache] keeps its data: a folder of files on Android and
/// Windows ([createOfflineStore] in offline_store_io.dart), the browser's
/// storage on the web build (offline_store_web.dart), or memory in tests.
abstract class OfflineStore {
  Future<String?> read(String name);
  Future<void> write(String name, String data);

  /// Deletes everything this store holds.
  Future<void> clear();
}

/// For tests (and anywhere nothing should touch the disk).
class MemoryOfflineStore implements OfflineStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String name) async => data[name];

  @override
  Future<void> write(String name, String value) async => data[name] = value;

  @override
  Future<void> clear() async => data.clear();
}

/// Rows the server sent, and when — the copy shown when there's no
/// connection.
class SavedRows {
  const SavedRows(this.savedAt, this.rows);

  final DateTime savedAt;
  final List<Map<String, dynamic>> rows;
}

/// The copy of the calendar kept on this device, so events that were
/// already loaded still show with no internet (e.g. somewhere without
/// signal). It holds the raw rows exactly as Supabase sent them, so they
/// turn back into events through the same code as live data
/// ([BarangayEvent.fromSupabase] — including the stored time convention).
///
/// Every name includes the signed-in account's id ([offlineCacheName]), so
/// someone else signing in on the same phone never sees another account's
/// group or personal events, and signing out deletes it all
/// ([SupabaseAuthService.signOut]). Failures to read or write are ignored:
/// the cache only ever helps, it never stops the app working.
class OfflineCache {
  OfflineCache([OfflineStore? store]) : _store = store ?? createOfflineStore();

  final OfflineStore _store;

  /// Writes per name, one after another, so two quick updates can't
  /// interleave on disk.
  final Map<String, Future<void>> _writes = {};

  Future<SavedRows?> readRows(String name) async {
    final json = await readJson(name);
    if (json is! Map) return null;
    final savedAt = DateTime.tryParse(json['saved_at'] as String? ?? '');
    final rows = json['rows'];
    if (savedAt == null || rows is! List) return null;
    return SavedRows(savedAt, [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ]);
  }

  Future<void> writeRows(String name, SavedRows saved) =>
      writeJson(name, {'saved_at': saved.savedAt.toIso8601String(), 'rows': saved.rows});

  Future<Object?> readJson(String name) async {
    try {
      final raw = await _store.read(name);
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null; // Missing, unreadable, or half-written: as if never saved.
    }
  }

  Future<void> writeJson(String name, Object json) {
    final previous = _writes[name] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        await _store.write(name, jsonEncode(json));
      } catch (_) {
        // Disk full, browser storage quota, ...: keep running without it.
      }
    });
    _writes[name] = next;
    return next;
  }

  Future<void> clear() async {
    try {
      await Future.wait(_writes.values);
      await _store.clear();
    } catch (_) {}
  }
}

/// The cache name for [what] ('events', 'calendars', 'profile') of the
/// account [userId] — 'guest' when nobody is signed in (Guest mode only
/// ever sees public events).
String offlineCacheName(String what, String? userId) => '$what-${userId ?? 'guest'}';

/// Whether the events on screen came live from the server, or are the copy
/// saved on this device because the server can't be reached.
class EventSyncStatus {
  const EventSyncStatus.online()
      : offline = false,
        savedAt = null;

  const EventSyncStatus.offline(this.savedAt) : offline = true;

  final bool offline;

  /// When the saved copy being shown was last updated from the server;
  /// null when this device has no saved copy yet.
  final DateTime? savedAt;
}

/// Whether [error] means "couldn't reach the server" rather than an answer
/// from it. A database error (a missing table, a permission problem) comes
/// back as a [PostgrestException]-like error with a code; everything else
/// (no network, a timed-out realtime connection) counts as offline.
typedef ConnectionErrorTest = bool Function(Object error);

/// Seconds to wait before trying the server again after [failures] failed
/// tries in a row: 5, 10, 20, 40, then every 60.
Duration offlineRetryDelay(int failures) =>
    Duration(seconds: [5, 10, 20, 40, 60][failures.clamp(0, 4)]);

/// A live table stream that first shows the copy saved on this device,
/// saves every update from the server for next time, and keeps trying the
/// server again while it can't be reached. [live] is called again for each
/// try (a Supabase `.stream()` that started offline doesn't recover by
/// itself). Errors never reach the listener; [onStatus], if given, hears
/// when the data goes stale (offline, with the saved copy's time) or live.
Stream<T> liveWithOfflineCopy<T>({
  required OfflineCache cache,
  required String name,
  required Stream<List<Map<String, dynamic>>> Function() live,
  required T Function(List<Map<String, dynamic>> rows) convert,
  required Map<String, SavedRows> latest,
  required ConnectionErrorTest isConnectionError,
  void Function(EventSyncStatus status)? onStatus,
  Duration Function(int failures) retryDelay = offlineRetryDelay,
}) {
  late final StreamController<T> controller;
  StreamSubscription<List<Map<String, dynamic>>>? subscription;
  Timer? retryTimer;
  var failures = 0;
  var hasLiveData = false;
  var offline = false;

  void connect() {
    unawaited(subscription?.cancel());
    subscription = live().listen(
      (rows) {
        failures = 0;
        hasLiveData = true;
        final saved = SavedRows(DateTime.now(), rows);
        latest[name] = saved;
        unawaited(cache.writeRows(name, saved));
        offline = false;
        onStatus?.call(const EventSyncStatus.online());
        if (!controller.isClosed) controller.add(convert(rows));
      },
      onError: (Object error, StackTrace _) {
        if (isConnectionError(error)) {
          offline = true;
          onStatus?.call(EventSyncStatus.offline(latest[name]?.savedAt));
        }
        retryTimer?.cancel();
        retryTimer = Timer(retryDelay(failures++), () {
          if (!controller.isClosed) connect();
        });
      },
    );
  }

  controller = StreamController<T>(
    onListen: () {
      connect();
      // Shown right away (memory first, then disk) — replaced as soon as
      // the server answers.
      unawaited(() async {
        final saved = latest[name] ?? await cache.readRows(name);
        if (saved == null || hasLiveData || controller.isClosed) return;
        latest[name] ??= saved;
        controller.add(convert(saved.rows));
        if (offline) onStatus?.call(EventSyncStatus.offline(saved.savedAt));
      }());
    },
    onCancel: () async {
      retryTimer?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
