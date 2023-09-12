import 'package:elastic_dashboard/services/globals.dart';
import 'package:elastic_dashboard/services/nt4_connection.dart';
import 'package:elastic_dashboard/widgets/nt4_widgets/nt4_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PowerDistribution extends StatelessWidget with NT4Widget {
  @override
  String type = 'PowerDistribution';

  static int numberOfChannels = 23;

  List<String> channelTopics = [];

  late String voltageTopic;
  late String currentTopic;

  PowerDistribution(
      {super.key, required topic, period = Globals.defaultPeriod}) {
    super.topic = topic;
    super.period = period;

    init();
  }

  PowerDistribution.fromJson(
      {super.key, required Map<String, dynamic> jsonData}) {
    super.topic = jsonData['topic'] ?? '';
    super.period = jsonData['period'] ?? Globals.defaultPeriod;

    init();
  }

  @override
  void init() {
    super.init();

    for (int channel = 0; channel <= numberOfChannels; channel++) {
      channelTopics.add('$topic/Chan$channel');
    }

    voltageTopic = '$topic/Voltage';
    currentTopic = '$topic/TotalCurrent';
  }

  @override
  void resetSubscription() {
    super.resetSubscription();

    channelTopics.clear();

    for (int channel = 0; channel <= numberOfChannels; channel++) {
      channelTopics.add('$topic/Chan$channel');
    }

    voltageTopic = '$topic/Voltage';
    currentTopic = '$topic/TotalCurrent';
  }

  Widget _getChannelsColumn(BuildContext context, int start, int end) {
    List<Widget> channels = [];

    for (int channel = start; channel <= end; channel++) {
      double current = nt4Connection
              .getLastAnnouncedValue(channelTopics[channel]) as double? ??
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
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
              child: Text('${current.toStringAsFixed(2)} A',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
            const SizedBox(width: 5),
            Text('Ch. $channel'),
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

  Widget _getReversedChannelsColumn(BuildContext context, int start, int end) {
    List<Widget> channels = [];

    for (int channel = start; channel >= end; channel--) {
      double current = nt4Connection
              .getLastAnnouncedValue(channelTopics[channel]) as double? ??
          0.0;

      channels.add(
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ch. $channel'),
            const SizedBox(width: 5),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
              child: Text('${current.toStringAsFixed(2)} A',
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
    notifier = context.watch<NT4WidgetNotifier?>();

    return StreamBuilder(
      stream: subscription?.periodicStream(),
      builder: (context, snapshot) {
        double voltage =
            nt4Connection.getLastAnnouncedValue(voltageTopic) as double? ?? 0.0;
        double totalCurrent =
            nt4Connection.getLastAnnouncedValue(currentTopic) as double? ?? 0.0;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Voltage
                Column(
                  children: [
                    const Text('Voltage'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 64.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${voltage.toStringAsFixed(2)} V',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 64.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${totalCurrent.toStringAsFixed(2)} A',
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
                  _getChannelsColumn(context, 0, 11),
                  _getReversedChannelsColumn(context, 23, 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
