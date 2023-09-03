import 'package:github/github.dart';
import 'package:version/version.dart';

class UpdateChecker {
  final GitHub _github;
  final String currentVersion;

  UpdateChecker({required this.currentVersion}) : _github = GitHub();

  Future<bool> isUpdateAvailable() async {
    try {
      Release latestRelease = await _github.repositories
          .getLatestRelease(RepositorySlug('Gold872', 'elastic-dashboard'));

      String? tagName = latestRelease.tagName;

      if (tagName == null) {
        return false;
      }
      if (!tagName.startsWith('v')) {
        return false;
      }

      String versionName = tagName.substring(1);

      Version current = Version.parse(currentVersion);
      Version latest = Version.parse(versionName);

      return current < latest;
    } catch (_) {
      return false;
    }
  }
}
