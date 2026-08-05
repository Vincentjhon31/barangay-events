import 'app_update_service.dart';

// The GitHub-release update checker makes no sense for a website (no app
// binary to update) and depends on dart:io (HttpClient), which has no
// implementation for the web compile target — so the web build simply never
// offers an update service. CalendarScreen.updateService is already nullable
// and every call site already no-ops gracefully on null (see
// _checkForUpdates in lib/main.dart).
AppUpdateService? createDefaultUpdateService({
  required String repositoryOwner,
  required String repositoryName,
}) => null;
