import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> booleanBoxJson = {
    'topic': 'Test/Boolean Value',
    'period': 0.100,
    'data_type': 'boolean',
    'true_color': Colors.green.value,
    'false_color': Colors.red.value,
    'true_icon': 'None',
    'false_icon': 'None',
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  Finder findColor(Color color) => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color != null &&
            (widget.decoration as BoxDecoration).color!.value == color.value,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Boolean Value',
          type: NT4TypeStr.kBool,
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Boolean Value': false,
      },
    );
  });

  test('Boolean box from json', () {
    NTWidgetModel booleanBoxModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Boolean Box',
      booleanBoxJson,
    );

    expect(booleanBoxModel.type, 'Boolean Box');
    expect(booleanBoxModel.runtimeType, BooleanBoxModel);
    expect(
        booleanBoxModel.getAvailableDisplayTypes(),
        unorderedEquals([
          'Boolean Box',
          'Toggle Switch',
          'Toggle Button',
          'Text Display',
        ]));

    if (booleanBoxModel is! BooleanBoxModel) {
      return;
    }

    expect(booleanBoxModel.trueColor, Color(Colors.green.value));
    expect(booleanBoxModel.falseColor, Color(Colors.red.value));
    expect(booleanBoxModel.trueIcon, 'None');
    expect(booleanBoxModel.falseIcon, 'None');
  });

  test('Boolean box to json', () {
    BooleanBoxModel booleanBoxModel = BooleanBoxModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Boolean Value',
      dataType: 'boolean',
      period: 0.100,
      trueColor: Colors.green,
      falseColor: Colors.red,
      trueIcon: 'None',
      falseIcon: 'None',
    );

    expect(booleanBoxModel.toJson(), booleanBoxJson);
  });

  testWidgets('Boolean box widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel booleanBoxModel = NTWidgetBuilder.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Boolean Box',
      booleanBoxJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: booleanBoxModel as BooleanBoxModel,
            child: const BooleanBox(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsNothing);
    expect(findColor(Colors.red), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Boolean Value', true);
    booleanBoxModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsOneWidget);
    expect(findColor(Colors.red), findsNothing);

    booleanBoxModel.trueIcon = 'Checkmark';
    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Boolean Value', false);
    booleanBoxModel.falseIcon = 'X';
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.clear), findsOneWidget);

    booleanBoxModel.falseIcon = 'Exclamation Point';
    await widgetTester.pumpAndSettle();
    expect(find.byIcon(Icons.priority_high), findsOneWidget);
  });
}
