import 'package:elastic_dashboard/services/log.dart';
import 'package:github/github.dart';
import 'package:version/version.dart';

class UpdateChecker {
  final GitHub _github;
  final String currentVersion;

  UpdateChecker({required this.currentVersion}) : _github = GitHub();

  Future<Object?> isUpdateAvailable() async {
    logger.info('Checking for updates');

    try {
      Release latestRelease = await _github.repositories
          .getLatestRelease(RepositorySlug('Gold872', 'elastic-dashboard'));

      String? tagName = latestRelease.tagName;

      if (tagName == null) {
        logger.error('Release tag not found in git repository');
        return 'Release tag not found';
      }
      if (!tagName.startsWith('v')) {
        logger.error('Invalid version name: $tagName');
        return 'Invalid version name: \'$tagName\'';
      }

      String versionName = tagName.substring(1);

      Version current = Version.parse(currentVersion);
      Version latest = Version.parse(versionName);

      return current < latest;
    } catch (error) {
      logger.error('Failed to check for updates', error);
      return error.toString();
    }
  }
}
