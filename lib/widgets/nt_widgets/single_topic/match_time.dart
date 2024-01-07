import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MatchTimeWidget extends NTWidget {
  static const String widgetType = 'Match Time';
  @override
  String type = widgetType;

  String timeDisplayMode = 'Minutes and Seconds';
  static final List<String> _timeDisplayOptions = [
    'Minutes and Seconds',
    'Seconds Only',
  ];

  int redStartTime = 15;
  int yellowStartTime = 30;

  MatchTimeWidget({
    super.key,
    required super.topic,
    this.timeDisplayMode = 'Minutes and Seconds',
    this.redStartTime = 15,
    this.yellowStartTime = 30,
    super.dataType,
    super.period,
  }) : super();

  MatchTimeWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    timeDisplayMode =
        tryCast(jsonData['time_display_mode']) ?? 'Minutes and Seconds';

    _timeDisplayOptions.firstWhere(
        (e) => e.toUpperCase() == timeDisplayMode.toUpperCase(),
        orElse: () => 'Minutes and Seconds');

    redStartTime =
        tryCast<num>(jsonData['red_start_time'])?.toInt() ?? redStartTime;
    yellowStartTime =
        tryCast<num>(jsonData['yellow_start_time'])?.toInt() ?? yellowStartTime;
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
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: Tooltip(
                  message:
                      'The time (in seconds) where time will begin to display in red',
                  waitDuration: const Duration(milliseconds: 750),
                  child: DialogTextInput(
                    label: 'Red Start Time',
                    initialText: redStartTime.toString(),
                    onSubmit: (value) {
                      int? newRedTime = int.tryParse(value);

                      if (newRedTime == null) {
                        return;
                      }

                      redStartTime = newRedTime;
                      refresh();
                    },
                    formatter: FilteringTextInputFormatter.digitsOnly,
                  ),
                ),
              ),
              Flexible(
                child: Tooltip(
                  message:
                      'The time (in seconds) where time will begin to display in yellow',
                  waitDuration: const Duration(milliseconds: 750),
                  child: DialogTextInput(
                    label: 'Yellow Start Time',
                    initialText: yellowStartTime.toString(),
                    onSubmit: (value) {
                      int? newYellowTime = int.tryParse(value);

                      if (newYellowTime == null) {
                        return;
                      }

                      yellowStartTime = newYellowTime;
                      refresh();
                    },
                    formatter: FilteringTextInputFormatter.digitsOnly,
                  ),
                ),
              ),
            ],
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
      'red_start_time': redStartTime,
      'yellow_start_time': yellowStartTime,
    };
  }

  Color _getTimeColor(num time) {
    if (time <= redStartTime) {
      return Colors.red;
    } else if (time <= yellowStartTime) {
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
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
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
