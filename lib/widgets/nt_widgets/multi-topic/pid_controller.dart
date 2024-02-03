import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PIDControllerWidget extends NTWidget {
  static const String widgetType = 'PIDController';
  @override
  String type = widgetType;

  late String kpTopicName;
  late String kiTopicName;
  late String kdTopicName;
  late String setpointTopicName;

  NT4Topic? kpTopic;
  NT4Topic? kiTopic;
  NT4Topic? kdTopic;
  NT4Topic? setpointTopic;

  TextEditingController? kpTextController;
  TextEditingController? kiTextController;
  TextEditingController? kdTextController;
  TextEditingController? setpointTextController;

  double kpLastValue = 0.0;
  double kiLastValue = 0.0;
  double kdLastValue = 0.0;
  double setpointLastValue = 0.0;

  PIDControllerWidget({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  PIDControllerWidget.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    kpTopicName = '$topic/p';
    kiTopicName = '$topic/i';
    kdTopicName = '$topic/d';
    setpointTopicName = '$topic/setpoint';
  }

  @override
  void resetSubscription() {
    kpTopicName = '$topic/p';
    kiTopicName = '$topic/i';
    kdTopicName = '$topic/d';
    setpointTopicName = '$topic/setpoint';

    kpTopic = null;
    kiTopic = null;
    kdTopic = null;
    setpointTopic = null;

    super.resetSubscription();
  }

  void _publishKP() {
    bool publishTopic = kpTopic == null;

    kpTopic ??= ntConnection.getTopicFromName(kpTopicName);

    double? data = double.tryParse(kpTextController?.text ?? '');

    if (kpTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(kpTopic!);
    }

    ntConnection.updateDataFromTopic(kpTopic!, data);
  }

  void _publishKI() {
    bool publishTopic = kiTopic == null;

    kiTopic ??= ntConnection.getTopicFromName(kiTopicName);

    double? data = double.tryParse(kiTextController?.text ?? '');

    if (kiTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(kiTopic!);
    }

    ntConnection.updateDataFromTopic(kiTopic!, data);
  }

  void _publishKD() {
    bool publishTopic = kdTopic == null;

    kdTopic ??= ntConnection.getTopicFromName(kdTopicName);

    double? data = double.tryParse(kdTextController?.text ?? '');

    if (kdTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(kdTopic!);
    }

    ntConnection.updateDataFromTopic(kdTopic!, data);
  }

  void _publishSetpoint() {
    bool publishTopic = setpointTopic == null;

    setpointTopic ??= ntConnection.getTopicFromName(setpointTopicName);

    double? data = double.tryParse(setpointTextController?.text ?? '');

    if (setpointTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.nt4Client.publishTopic(setpointTopic!);
    }

    ntConnection.updateDataFromTopic(setpointTopic!, data);
  }

  @override
  List<Object> getCurrentData() {
    double kP = tryCast(ntConnection.getLastAnnouncedValue(kpTopicName)) ?? 0.0;
    double kI = tryCast(ntConnection.getLastAnnouncedValue(kiTopicName)) ?? 0.0;
    double kD = tryCast(ntConnection.getLastAnnouncedValue(kdTopicName)) ?? 0.0;
    double setpoint =
        tryCast(ntConnection.getLastAnnouncedValue(setpointTopicName)) ?? 0.0;

    return [
      kP,
      kI,
      kD,
      setpoint,
      kpLastValue,
      kiLastValue,
      kdLastValue,
      setpointLastValue,
      kpTextController?.text ?? '',
      kiTextController?.text ?? '',
      kdTextController?.text ?? '',
      setpointTextController?.text ?? '',
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
        stream: multiTopicPeriodicStream,
        builder: (context, snapshot) {
          double kP =
              tryCast(ntConnection.getLastAnnouncedValue(kpTopicName)) ?? 0.0;
          double kI =
              tryCast(ntConnection.getLastAnnouncedValue(kiTopicName)) ?? 0.0;
          double kD =
              tryCast(ntConnection.getLastAnnouncedValue(kdTopicName)) ?? 0.0;
          double setpoint =
              tryCast(ntConnection.getLastAnnouncedValue(setpointTopicName)) ??
                  0.0;

          // Creates the text editing controllers if they are null
          kpTextController ??= TextEditingController(text: kP.toString());
          kiTextController ??= TextEditingController(text: kI.toString());
          kdTextController ??= TextEditingController(text: kD.toString());
          setpointTextController ??=
              TextEditingController(text: setpoint.toString());

          // Updates the text of the text editing controller if the kp value has changed
          if (kP != kpLastValue) {
            kpTextController!.text = kP.toString();
          }
          kpLastValue = kP;

          // Updates the text of the text editing controller if the ki value has changed
          if (kI != kiLastValue) {
            kiTextController!.text = kI.toString();
          }
          kiLastValue = kI;

          // Updates the text of the text editing controller if the kd value has changed
          if (kD != kdLastValue) {
            kdTextController!.text = kD.toString();
          }
          kdLastValue = kD;

          // Updates the text of the text editing controller if the setpoint value has changed
          if (setpoint != setpointLastValue) {
            setpointTextController!.text = setpoint.toString();
          }
          setpointLastValue = setpoint;

          TextStyle labelStyle = Theme.of(context)
              .textTheme
              .bodyLarge!
              .copyWith(fontWeight: FontWeight.bold);

          bool showWarning = kP != double.tryParse(kpTextController!.text) ||
              kI != double.tryParse(kiTextController!.text) ||
              kD != double.tryParse(kdTextController!.text) ||
              setpoint != double.tryParse(setpointTextController!.text);

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
                      textEditingController: kpTextController,
                      initialText: kpTextController!.text,
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
                      textEditingController: kiTextController,
                      initialText: kiTextController!.text,
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
                      textEditingController: kdTextController,
                      initialText: kdTextController!.text,
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
                  Text('Setpoint', style: labelStyle),
                  const Spacer(),
                  Flexible(
                    flex: 5,
                    child: DialogTextInput(
                      textEditingController: setpointTextController,
                      initialText: setpointTextController!.text,
                      label: 'Setpoint',
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
                      _publishSetpoint();
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
