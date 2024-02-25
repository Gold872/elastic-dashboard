import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PowerDistributionModel extends NTWidgetModel {
  @override
  String type = PowerDistribution.widgetType;

  static const int numberOfChannels = 23;

  final List<String> channelTopics = [];

  String get voltageTopic => '$topic/Voltage';
  String get currentTopic => '$topic/TotalCurrent';

  PowerDistributionModel({required super.topic, super.dataType, super.period})
      : super();

  PowerDistributionModel.fromJson({required super.jsonData}) : super.fromJson();

  @override
  void init() {
    super.init();

    for (int channel = 0; channel <= numberOfChannels; channel++) {
      channelTopics.add('$topic/Chan$channel');
    }
  }

  @override
  void resetSubscription() {
    channelTopics.clear();

    for (int channel = 0; channel <= numberOfChannels; channel++) {
      channelTopics.add('$topic/Chan$channel');
    }

    super.resetSubscription();
  }

  @override
  List<Object> getCurrentData() {
    List<Object> data = [];

    double voltage =
        tryCast(ntConnection.getLastAnnouncedValue(voltageTopic)) ?? 0.0;
    double totalCurrent =
        tryCast(ntConnection.getLastAnnouncedValue(currentTopic)) ?? 0.0;

    data.addAll([voltage, totalCurrent]);

    for (String channel in channelTopics) {
      data.add(tryCast(ntConnection.getLastAnnouncedValue(channel)) ?? 0.0);
    }

    return data;
  }
}

class PowerDistribution extends NTWidget {
  static const String widgetType = 'PowerDistribution';

  const PowerDistribution({super.key}) : super();

  Widget _getChannelsColumn(
      PowerDistributionModel model, BuildContext context, int start, int end) {
    List<Widget> channels = [];

    for (int channel = start; channel <= end; channel++) {
      double current = tryCast(ntConnection
              .getLastAnnouncedValue(model.channelTopics[channel])) ??
          0.0;

      channels.add(
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Text('${current.toStringAsFixed(2).padLeft(5, '0')} A',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
            const SizedBox(width: 10),
            Text('Ch. ${channel.toString().padRight(2)}'),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [...channels],
    );
  }

  Widget _getReversedChannelsColumn(
      PowerDistributionModel model, BuildContext context, int start, int end) {
    List<Widget> channels = [];

    for (int channel = start; channel >= end; channel--) {
      double current = tryCast(ntConnection
              .getLastAnnouncedValue(model.channelTopics[channel])) ??
          0.0;

      channels.add(
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ch. $channel'),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Text('${current.toStringAsFixed(2).padLeft(5, '0')} A',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [...channels],
    );
  }

  @override
  Widget build(BuildContext context) {
    PowerDistributionModel model = cast(context.watch<NTWidgetModel>());

    return StreamBuilder(
      stream: model.multiTopicPeriodicStream,
      builder: (context, snapshot) {
        double voltage =
            tryCast(ntConnection.getLastAnnouncedValue(model.voltageTopic)) ??
                0.0;
        double totalCurrent =
            tryCast(ntConnection.getLastAnnouncedValue(model.currentTopic)) ??
                0.0;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Voltage
                Column(
                  children: [
                    const Text('Voltage'),
                    const SizedBox(height: 2.5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${voltage.toStringAsFixed(2).padLeft(5, '0')} V',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                // Current
                Column(
                  children: [
                    const Text('Total Current'),
                    const SizedBox(height: 2.5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${totalCurrent.toStringAsFixed(2).padLeft(5, '0')} A',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Channel current
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // First 12 channels
                  _getChannelsColumn(model, context, 0, 11),
                  _getReversedChannelsColumn(model, context, 23, 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
