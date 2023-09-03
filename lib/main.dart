import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await windowManager.ensureInitialized();

  Globals.gridSize = preferences.getInt(PrefKeys.gridSize) ?? 128;
  Globals.snapToGrid = preferences.getBool(PrefKeys.snapToGrid) ?? true;
  Globals.showGrid = preferences.getBool(PrefKeys.showGrid) ?? false;

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

  await windowManager.setMinimumSize(const Size(1280, 720));
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
      windowButtonVisibility: false);

  runApp(Elastic(preferences: preferences));
}

class Elastic extends StatefulWidget {
  final SharedPreferences preferences;

  const Elastic({super.key, required this.preferences});

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
        onColorChanged: (color) => setState(() {
          teamColor = color;
          widget.preferences.setInt('team_color', color.value);
        }),
      ),
    );
  }
}
