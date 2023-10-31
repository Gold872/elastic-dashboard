import 'dart:ui';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  await windowManager.ensureInitialized();

  Globals.gridSize = preferences.getInt(PrefKeys.gridSize) ?? Globals.gridSize;
  Globals.snapToGrid =
      preferences.getBool(PrefKeys.snapToGrid) ?? Globals.snapToGrid;
  Globals.showGrid = preferences.getBool(PrefKeys.showGrid) ?? Globals.showGrid;
  Globals.cornerRadius =
      preferences.getDouble(PrefKeys.cornerRadius) ?? Globals.cornerRadius;

  nt4Connection
      .nt4Connect(preferences.getString(PrefKeys.ipAddress) ?? '127.0.0.1');

  nt4Connection.dsClientConnect((ip) async {
    if (preferences.getString(PrefKeys.ipAddress) != ip) {
      await preferences.setString(PrefKeys.ipAddress, ip);
    } else {
      return;
    }

    nt4Connection.changeIPAddress(ip);
  });

  await FieldImages.loadFields('assets/fields/');

  FlutterView screenView = PlatformDispatcher.instance.views.first;
  Size screenSize = screenView.physicalSize * screenView.devicePixelRatio;

  await windowManager.setMinimumSize(screenSize * 0.55);
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
      windowButtonVisibility: false);

  await windowManager.show();
  await windowManager.focus();

  runApp(Elastic(version: packageInfo.version, preferences: preferences));
}

class Elastic extends StatefulWidget {
  final SharedPreferences preferences;
  final String version;

  const Elastic({super.key, required this.version, required this.preferences});

  @override
  State<Elastic> createState() => _ElasticState();
}

class _ElasticState extends State<Elastic> {
  late Color teamColor = Color(
      widget.preferences.getInt(PrefKeys.teamColor) ?? Colors.blueAccent.value);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: teamColor,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Elastic',
      theme: theme,
      home: DashboardPage(
        connectionStream: nt4Connection.connectionStatus(),
        preferences: widget.preferences,
        version: widget.version,
        onColorChanged: (color) => setState(() {
          teamColor = color;
          widget.preferences.setInt('team_color', color.value);
        }),
      ),
    );
  }
}
