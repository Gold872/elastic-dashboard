import 'package:elastic_dashboard/services/ip_address_util.dart';

class Settings {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic-dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static String ipAddress = '127.0.0.1';
  static int teamNumber = 9999;
  static int gridSize = 128;
  static bool layoutLocked = false;
  static double cornerRadius = 15.0;
  static bool snapToGrid = true;
  static bool autoResizeToDS = false;
  static bool autoSwitchTabs = false;

  static bool isWindowDraggable = true;
  static bool isWindowMaximizable = true;

  static double defaultPeriod = 0.06;
  static double defaultGraphPeriod = 0.033;
  static bool autoSave = false;

  static final Map<String, dynamic> _settings = {
    'repositoryLink': repositoryLink,
    'releasesLink': releasesLink,
    'ipAddressMode': ipAddressMode,
    'ipAddress': ipAddress,
    'teamNumber': teamNumber,
    'gridSize': gridSize,
    'layoutLocked': layoutLocked,
    'cornerRadius': cornerRadius,
    'snapToGrid': snapToGrid,
    'autoResizeToDS': autoResizeToDS,
    'autoSwitchTabs': autoSwitchTabs,
    'isWindowDraggable': isWindowDraggable,
    'isWindowMaximizable': isWindowMaximizable,
    'defaultPeriod': defaultPeriod,
    'defaultGraphPeriod': defaultGraphPeriod,
    'autoSave': autoSave,
  };

  static dynamic get(String key) => _settings[key];

  static void set(String key, dynamic value) {
    _settings[key] = value;
    switch (key) {
      case 'ipAddressMode':
        ipAddressMode = value;
        break;
      case 'ipAddress':
        ipAddress = value;
        break;
      case 'teamNumber':
        teamNumber = value;
        break;
      case 'gridSize':
        gridSize = value;
        break;
      case 'layoutLocked':
        layoutLocked = value;
        break;
      case 'cornerRadius':
        cornerRadius = value;
        break;
      case 'snapToGrid':
        snapToGrid = value;
        break;
      case 'autoResizeToDS':
        autoResizeToDS = value;
        break;
      case 'autoSwitchTabs': // Added case for autoSwitchTabs
        autoSwitchTabs = value;
        break;
      case 'isWindowDraggable':
        isWindowDraggable = value;
        break;
      case 'isWindowMaximizable':
        isWindowMaximizable = value;
        break;
      case 'defaultPeriod':
        defaultPeriod = value;
        break;
      case 'defaultGraphPeriod':
        defaultGraphPeriod = value;
        break;
      case 'autoSave':
        autoSave = value;
        break;
      default:
        throw ArgumentError('Invalid settings key: $key');
    }
  }
}

class PrefKeys {
  static const layout = 'layout';
  static const ipAddress = 'ip_address';
  static const ipAddressMode = 'ip_address_mode';
  static const teamNumber = 'team_number';
  static const teamColor = 'team_color';
  static const layoutLocked = 'layout_locked';
  static const gridSize = 'grid_size';
  static const cornerRadius = 'corner_radius';
  static const snapToGrid = 'show_grid';
  static const autoResizeToDS = 'auto_resize_to_driver_station';
  static const rememberWindowPosition = 'remember_window_position';
  static const defaultPeriod = 'default_period';
  static const defaultGraphPeriod = 'default_graph_period';
  static const windowPosition = 'window_position';
  static const autoSave = 'auto_save';
  static const autoSwitchTabs = 'auto_switch_tabs';
}
