// Picks where the offline copy is kept: files on Android/Windows (dart:io),
// the browser's storage on the web build — same pattern as
// app_update_service_factory.dart.
export 'offline_store_web.dart' if (dart.library.io) 'offline_store_io.dart';
