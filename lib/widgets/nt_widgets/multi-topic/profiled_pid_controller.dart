import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ProfiledPIDControllerWidget extends NTWidget {
  static const String widgetType = 'ProfiledPIDController';
  @override
  String type = widgetType;

  late String _kpTopicName;
  late String _kiTopicName;
  late String _kdTopicName;
  late String _goalTopicName;

  NT4Topic? _kpTopic;
  NT4Topic? _kiTopic;
  NT4Topic? _kdTopic;
  NT4Topic? _goalTopic;

  TextEditingController? _kpTextController;
  TextEditingController? _kiTextController;
  TextEditingController? _kdTextController;
  TextEditingController? _goalTextController;

  double _kpLastValue = 0.0;
  double _kiLastValue = 0.0;
  double _kdLastValue = 0.0;
  double _goalLastValue = 0.0;

  ProfiledPIDControllerWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ProfiledPIDControllerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    _kpTopicName = '$topic/p';
    _kiTopicName = '$topic/i';
    _kdTopicName = '$topic/d';
    _goalTopicName = '$topic/goal';
  }

  @override
  void resetSubscription() {
    _kpTopicName = '$topic/p';
    _kiTopicName = '$topic/i';
    _kdTopicName = '$topic/d';
    _goalTopicName = '$topic/setpoint';

    _kpTopic = null;
    _kiTopic = null;
    _kdTopic = null;
    _goalTopic = null;

    super.resetSubscription();
  }

  void _publishKP() {
    bool publishTopic = _kpTopic == null;

    _kpTopic ??= ntConnection.getTopicFromName(_kpTopicName);

    double? data = double.tryParse(_kpTextController?.text ?? '');

    if (_kpTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(_kpTopic!);
    }

    ntConnection.updateDataFromTopic(_kpTopic!, data);
  }

  void _publishKI() {
    bool publishTopic = _kiTopic == null;

    _kiTopic ??= ntConnection.getTopicFromName(_kiTopicName);

    double? data = double.tryParse(_kiTextController?.text ?? '');

    if (_kiTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(_kiTopic!);
    }

    ntConnection.updateDataFromTopic(_kiTopic!, data);
  }

  void _publishKD() {
    bool publishTopic = _kdTopic == null;

    _kdTopic ??= ntConnection.getTopicFromName(_kdTopicName);

    double? data = double.tryParse(_kdTextController?.text ?? '');

    if (_kdTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(_kdTopic!);
    }

    ntConnection.updateDataFromTopic(_kdTopic!, data);
  }

  void _publishGoal() {
    bool publishTopic = _goalTopic == null;

    _goalTopic ??= ntConnection.getTopicFromName(_goalTopicName);

    double? data = double.tryParse(_goalTextController?.text ?? '');

    if (_goalTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(_goalTopic!);
    }

    ntConnection.updateDataFromTopic(_goalTopic!, data);
  }

  @override
  List<Object> getCurrentData() {
    double kP =
        tryCast(ntConnection.getLastAnnouncedValue(_kpTopicName)) ?? 0.0;
    double kI =
        tryCast(ntConnection.getLastAnnouncedValue(_kiTopicName)) ?? 0.0;
    double kD =
        tryCast(ntConnection.getLastAnnouncedValue(_kdTopicName)) ?? 0.0;
    double goal =
        tryCast(ntConnection.getLastAnnouncedValue(_goalTopicName)) ?? 0.0;

    return [
      kP,
      kI,
      kD,
      goal,
      _kpLastValue,
      _kiLastValue,
      _kdLastValue,
      _goalLastValue,
      _kpTextController?.text ?? '',
      _kiTextController?.text ?? '',
      _kdTextController?.text ?? '',
      _goalTextController?.text ?? '',
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
        stream: multiTopicPeriodicStream,
        builder: (context, snapshot) {
          double kP =
              tryCast(ntConnection.getLastAnnouncedValue(_kpTopicName)) ?? 0.0;
          double kI =
              tryCast(ntConnection.getLastAnnouncedValue(_kiTopicName)) ?? 0.0;
          double kD =
              tryCast(ntConnection.getLastAnnouncedValue(_kdTopicName)) ?? 0.0;
          double goal =
              tryCast(ntConnection.getLastAnnouncedValue(_goalTopicName)) ??
                  0.0;

          // Creates the text editing controllers if they are null
          _kpTextController ??= TextEditingController(text: kP.toString());
          _kiTextController ??= TextEditingController(text: kI.toString());
          _kdTextController ??= TextEditingController(text: kD.toString());
          _goalTextController ??= TextEditingController(text: goal.toString());

          // Updates the text of the text editing controller if the kp value has changed
          if (kP != _kpLastValue) {
            _kpTextController!.text = kP.toString();
          }
          _kpLastValue = kP;

          // Updates the text of the text editing controller if the ki value has changed
          if (kI != _kiLastValue) {
            _kiTextController!.text = kI.toString();
          }
          _kiLastValue = kI;

          // Updates the text of the text editing controller if the kd value has changed
          if (kD != _kdLastValue) {
            _kdTextController!.text = kD.toString();
          }
          _kdLastValue = kD;

          // Updates the text of the text editing controller if the setpoint value has changed
          if (goal != _goalLastValue) {
            _goalTextController!.text = goal.toString();
          }
          _goalLastValue = goal;

          TextStyle labelStyle = Theme.of(context)
              .textTheme
              .bodyLarge!
              .copyWith(fontWeight: FontWeight.bold);

          bool showWarning = kP != double.tryParse(_kpTextController!.text) ||
              kI != double.tryParse(_kiTextController!.text) ||
              kD != double.tryParse(_kdTextController!.text) ||
              goal != double.tryParse(_goalTextController!.text);

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // kP
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('P', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: _kpTextController,
                      initialText: _kpTextController!.text,
                      label: 'kP',
                      formatter: Constants.decimalTextFormatter(),
                      onSubmit: (value) {},
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              // kI
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('I', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: _kiTextController,
                      initialText: _kiTextController!.text,
                      label: 'kI',
                      formatter: Constants.decimalTextFormatter(),
                      onSubmit: (value) {},
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              // kD
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  Text('D', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: _kdTextController,
                      initialText: _kdTextController!.text,
                      label: 'kD',
                      formatter: Constants.decimalTextFormatter(),
                      onSubmit: (value) {},
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              Row(
                children: [
                  const Spacer(),
                  Text('Goal', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: _goalTextController,
                      initialText: _goalTextController!.text,
                      label: 'Goal',
                      formatter:
                          Constants.decimalTextFormatter(allowNegative: true),
                      onSubmit: (value) {},
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      _publishKP();
                      _publishKI();
                      _publishKD();
                      _publishGoal();
                    },
                    style: ButtonStyle(
                      shape: MaterialStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                      ),
                    ),
                    child: const Text('Publish Values'),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    (showWarning) ? Icons.priority_high : Icons.check,
                    color: (showWarning) ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ],
          );
        });
  }
}
