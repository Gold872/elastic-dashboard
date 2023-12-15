import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';

class MatchTimeWidget extends NT4Widget {
  static const String widgetType = 'Match Time';
  @override
  String type = widgetType;

  String timeDisplayMode = 'Minutes and Seconds';
  static final List<String> _timeDisplayOptions = [
    'Minutes and Seconds',
    'Seconds Only',
  ];

  MatchTimeWidget({
    super.key,
    required super.topic,
    this.timeDisplayMode = 'Minutes and Seconds',
    super.period,
  }) : super();

  MatchTimeWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    timeDisplayMode =
        tryCast(jsonData['time_display_mode']) ?? 'Minutes and Seconds';

    _timeDisplayOptions.firstWhere(
        (e) => e.toUpperCase() == timeDisplayMode.toUpperCase(),
        orElse: () => 'Minutes and Seconds');
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Column(
        children: [
          const Text('Time Display Mode'),
          DialogDropdownChooser<String>(
            initialValue: timeDisplayMode,
            choices: const ['Minutes and Seconds', 'Seconds Only'],
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              timeDisplayMode = value;

              refresh();
            },
          ),
        ],
      ),
    ];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'time_display_mode': timeDisplayMode,
    };
  }

  Color _getTimeColor(num time) {
    if (time <= 15.0) {
      return Colors.red;
    } else if (time <= 30.0) {
      return Colors.yellow;
    } else if (time <= 60.0) {
      return Colors.green;
    }

    return Colors.blue;
  }

  String _secondsToMinutes(num time) {
    return '${(time / 60.0).floor()}:${(time % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: nt4Connection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        notifier = context.watch<NT4WidgetNotifier?>();

        double time = tryCast(snapshot.data) ?? -1.0;
        time = time.floorToDouble();

        String timeDisplayString;
        if (timeDisplayMode == 'Minutes and Seconds' && time >= 0) {
          timeDisplayString = _secondsToMinutes(time.toInt());
        } else {
          timeDisplayString = time.toInt().toString();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  timeDisplayString,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.0,
                    color: _getTimeColor(time),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
