import 'package:github/github.dart';
import 'package:version/version.dart';

import 'package:elastic_dashboard/services/log.dart';

class UpdateChecker {
  final GitHub _github;
  final String currentVersion;

  UpdateChecker({required this.currentVersion}) : _github = GitHub();

  Future<UpdateCheckerResponse> isUpdateAvailable() async {
    logger.info('Checking for updates');

    Version current = Version.parse(currentVersion);

    if (current.major == 2027 && current.preRelease.isNotEmpty) {
      String alphaInfo = current.preRelease.first;
      int alphaNumber = int.parse(alphaInfo.split('alpha').last);

      String nextVersion = current.toString().replaceAll(
            alphaInfo,
            'alpha${alphaNumber + 1}',
          );

      try {
        await _github.repositories.getReleaseByTagName(
          RepositorySlug('Gold872', 'elastic-dashboard'),
          'v$nextVersion',
        );

        return UpdateCheckerResponse(
          updateAvailable: true,
          latestVersion: nextVersion,
          error: false,
        );
      } catch (error) {
        if (error.toString().contains(
            'GitHub Error: Release for tagName v$nextVersion Not Found.')) {
          logger.debug('Error when checking for 2027 alpha update', error);
          return UpdateCheckerResponse(
            updateAvailable: false,
            latestVersion: current.toString(),
            error: false,
          );
        }
        return UpdateCheckerResponse(
          updateAvailable: false,
          errorMessage: error.toString(),
          error: true,
        );
      }
    }

    try {
      Release latestRelease = await _github.repositories
          .getLatestRelease(RepositorySlug('Gold872', 'elastic-dashboard'));

      String? tagName = latestRelease.tagName;

      if (tagName == null) {
        logger.error('Release tag not found in git repository');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Release tag not found',
        );
      }
      if (!tagName.startsWith('v')) {
        logger.error('Invalid version name: $tagName');
        return UpdateCheckerResponse(
          updateAvailable: false,
          error: true,
          errorMessage: 'Invalid version name: \'$tagName\'',
        );
      }

      String versionName = tagName.substring(1);

      Version latest = Version.parse(versionName);

      bool updateAvailable = current < latest;

      return UpdateCheckerResponse(
        updateAvailable: updateAvailable,
        latestVersion: latest.toString(),
        error: false,
      );
    } catch (error) {
      logger.error('Failed to check for updates', error);
      return UpdateCheckerResponse(
        updateAvailable: false,
        error: true,
        errorMessage: error.toString(),
      );
    }
  }
}

class UpdateCheckerResponse {
  final bool updateAvailable;
  final String? latestVersion;
  final bool error;
  final String? errorMessage;

  bool get onLatestVersion => !updateAvailable && !error;

  UpdateCheckerResponse({
    required this.updateAvailable,
    this.latestVersion,
    required this.error,
    this.errorMessage,
  });
}
