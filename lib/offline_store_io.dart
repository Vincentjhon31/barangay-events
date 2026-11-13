import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'offline_cache.dart';

OfflineStore createOfflineStore() => FileOfflineStore();

/// One JSON file per name in the app's private support folder ("offline"),
/// which other apps can't read. Each write goes to a temporary file first
/// and then replaces the old one, so a crash mid-write never leaves a
/// half-written copy behind.
class FileOfflineStore implements OfflineStore {
  FileOfflineStore({Future<Directory> Function()? directory})
      : _directory = directory ?? (() async => Directory('${(await getApplicationSupportDirectory()).path}/offline'));

  final Future<Directory> Function() _directory;
  Future<Directory>? _resolved;

  Future<Directory> get _dir => _resolved ??= _directory().then((dir) async {
        await dir.create(recursive: true);
        return dir;
      });

  Future<File> _file(String name) async => File('${(await _dir).path}/$name.json');

  @override
  Future<String?> read(String name) async {
    final file = await _file(name);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String name, String data) async {
    final file = await _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is File) await entry.delete();
    }
  }
}
