import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';

class ShuffleboardNTListener {
  static const String shuffleboardTableRoot = '/Shuffleboard';
  static const String metadataTable = '$shuffleboardTableRoot/.metadata';
  static const String tabsEntry = '$metadataTable/Tabs';
  static const String selectedEntry = '$metadataTable/Selected';

  final Function(Map<String, dynamic> widgetData)? onWidgetAdded;
  final Function(String tab)? onTabChanged;

  late NT4Subscription selectedSubscription;

  String? previousSelection;

  ShuffleboardNTListener({this.onTabChanged, this.onWidgetAdded});

  void initializeSubscriptions() {
    selectedSubscription =
        nt4Connection.subscribe(selectedEntry, Globals.defaultPeriod);
  }

  void initializeListeners() {
    selectedSubscription.periodicStream().listen((data) {
      if (data is! String?) {
        return;
      }

      if (data != previousSelection && data != null) {
        _handleTabChange(data);
      }

      previousSelection = data;
    });

    nt4Connection.nt4Client.addTopicAnnounceListener((topic) {
      if (topic.name.indexOf(metadataTable) != 0) {
        return;
      }
    });
  }

  void _handleTabChange(String newTab) {
    onTabChanged?.call(newTab);
  }
}
