import 'package:elastic_dashboard/services/ip_address_util.dart';

class Settings {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic-dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static String ipAddress = '127.0.0.1';
  static int teamNumber = 353;
  static int gridSize = 128;
  static double cornerRadius = 15.0;
  static bool showGrid = false;
  static bool autoResizeToDS = false;

  // window_manager doesn't support drag disable/maximize
  // disable on some platforms, this is a dumb workaround for it
  static bool isWindowDraggable = true;
  static bool isWindowMaximizable = true;

  static double defaultPeriod = 0.1;
  static double defaultGraphPeriod = 0.033;
}

class PrefKeys {
  static String layout = 'layout';
  static String ipAddress = 'ip_address';
  static String ipAddressMode = 'ip_address_mode';
  static String teamNumber = 'team_number';
  static String teamColor = 'team_color';
  static String gridSize = 'grid_size';
  static String cornerRadius = 'corner_radius';
  static String showGrid = 'show_grid';
  static String autoResizeToDS = 'auto_resize_to_driver_station';
  static String defaultPeriod = 'default_period';
  static String defaultGraphPeriod = 'default_graph_period';
}
