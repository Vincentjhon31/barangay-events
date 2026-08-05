import 'app_update_service.dart';
import 'app_update_service_io.dart';

AppUpdateService? createDefaultUpdateService({
  required String repositoryOwner,
  required String repositoryName,
}) {
  return GitHubReleaseUpdateService(
    repositoryOwner: repositoryOwner,
    repositoryName: repositoryName,
  );
}
