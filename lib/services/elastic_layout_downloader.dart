import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';

typedef LayoutDownloadResponse = ({bool successful, String data});

class ElasticLayoutDownloader {
  final Client client = Client();

  Future<LayoutDownloadResponse> downloadLayout({
    required NTConnection ntConnection,
    required SharedPreferences preferences,
  }) async {
    if (!ntConnection.isNT4Connected) {
      return (
        successful: false,
        data:
            'Cannot download a remote layout while disconnected from the robot.'
      );
    }
    String robotIP =
        preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress;
    Uri robotUri = Uri.parse(
      'http://$robotIP:5800/elastic_layout.json',
    );
    Response response;
    try {
      response = await client.get(robotUri);
    } on ClientException catch (e) {
      return (successful: false, data: e.message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = switch (response.statusCode) {
        404 =>
          'File "elastic_layout.json" was not found, ensure that you have deployed a file named "elastic_layout.json" in the deploy directory',
        _ => 'Request returned status code ${response.statusCode}',
      };

      return (successful: false, data: errorMessage);
    }
    return (successful: true, data: response.body);
  }
}
