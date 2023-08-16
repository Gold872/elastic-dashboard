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

  Globals.gridSize = preferences.getInt('grid_size') ?? 128;
  Globals.snapToGrid = preferences.getBool('snap_to_grid') ?? true;
  Globals.showGrid = preferences.getBool('show_grid') ?? false;

  nt4Connection.connect();

  await FieldImages.loadFields('assets/fields/');

  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

  runApp(Elastic(preferences: preferences));
}

class Elastic extends StatelessWidget {
  final SharedPreferences preferences;

  const Elastic({super.key, required this.preferences});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blueAccent,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Elastic',
      theme: theme,
      home: DashboardPage(
        connectionStream: nt4Connection.connectionStatus(),
        preferences: preferences,
      ),
    );
  }
}
