import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache.dart';

OfflineStore createOfflineStore() => PrefsOfflineStore();

/// The web build has no files to write, so the copy goes in the browser's
/// storage (through shared_preferences), under "offline_<name>" keys. A
/// browser that's out of room just skips saving (see [OfflineCache]).
class PrefsOfflineStore implements OfflineStore {
  static const String _prefix = 'offline_';

  @override
  Future<String?> read(String name) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$name');

  @override
  Future<void> write(String name, String data) async {
    await (await SharedPreferences.getInstance()).setString('$_prefix$name', data);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}
