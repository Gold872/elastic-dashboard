import 'package:elastic_dashboard/services/ip_address_util.dart';

class Globals {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic-dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static String ipAddress = '127.0.0.1';
  static int teamNumber = 353;
  static int gridSize = 128;
  static double cornerRadius = 15.0;
  static bool snapToGrid = true;
  static bool showGrid = false;

  static const double defaultPeriod = 0.1;
  static const double defaultGraphPeriod = 0.033;

  static const String roboRIODefaultIP = '192.168.7.201';
}

class PrefKeys {
  static String layout = 'layout';
  static String ipAddress = 'ip_address';
  static String ipAddressMode = 'ip_address_mode';
  static String teamNumber = 'team_number';
  static String teamColor = 'team_color';
  static String gridSize = 'grid_size';
  static String cornerRadius = 'corner_radius';
  static String snapToGrid = 'snap_to_grid';
  static String showGrid = 'show_grid';
}
