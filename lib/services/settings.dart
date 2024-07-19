import 'package:flex_seed_scheme/flex_seed_scheme.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';

class Settings {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic-dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  // window_manager doesn't support drag disable/maximize
  // disable on some platforms, this is a dumb workaround for it
  static bool isWindowDraggable = true;
  static bool isWindowMaximizable = true;
}

class Defaults {
  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static FlexSchemeVariant themeVariant = FlexSchemeVariant.material3Legacy;
  static const String defaultVariantName = 'Material-3 Legacy (Default)';

  static const String ipAddress = '127.0.0.1';
  static const int teamNumber = 9999;
  static const int gridSize = 128;
  static const bool layoutLocked = false;
  static const double cornerRadius = 15.0;
  static const bool showGrid = true;
  static const bool autoResizeToDS = false;

  static const double defaultPeriod = 0.06;
  static const double defaultGraphPeriod = 0.033;
}

class PrefKeys {
  static String layout = 'layout';
  static String ipAddress = 'ip_address';
  static String ipAddressMode = 'ip_address_mode';
  static String teamNumber = 'team_number';
  static String teamColor = 'team_color';
  static String themeVariant = 'theme_variant';
  static String layoutLocked = 'layout_locked';
  static String gridSize = 'grid_size';
  static String cornerRadius = 'corner_radius';
  static String showGrid = 'show_grid';
  static String autoResizeToDS = 'auto_resize_to_driver_station';
  static String rememberWindowPosition = 'remember_window_position';
  static String defaultPeriod = 'default_period';
  static String defaultGraphPeriod = 'default_graph_period';

  static String windowPosition = 'window_position';
}
