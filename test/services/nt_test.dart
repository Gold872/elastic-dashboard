import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';

void main() {
  test('NT4 Client', () {
    bool connected = false;

    NT4Client client = NT4Client(
      serverBaseAddress: '10.3.53.2',
      onConnect: () => connected = true,
      onDisconnect: () => connected = false,
    );

    expect(connected, false);

    // Subscribing
    NT4Subscription subscription1 =
        client.subscribe('/SmartDashboard/Test Number');

    expect(client.subscriptions.length, greaterThanOrEqualTo(1));

    expect(client.lastAnnouncedValues.isEmpty, true);

    // Publishing and adding to the last announced values
    client.addSample(
        NT4Topic(
            name: '/SmartDashboard/Test Number',
            type: NT4TypeStr.kFloat32,
            properties: {}),
        3.53);

    expect(client.lastAnnouncedValues.isEmpty, false);

    expect(subscription1.currentValue != null, true);

    NT4Subscription subscription2 =
        client.subscribe('/SmartDashboard/Test Number');

    // If the subscriptions are shared
    expect(client.subscribedTopics.length, 1);

    client.unSubscribe(subscription1);

    expect(client.subscribedTopics.length, 1);

    client.unSubscribe(subscription2);

    expect(client.subscribedTopics.length, 0);

    // Changing ip address
    expect(client.lastAnnouncedValues.isEmpty, false);

    client.setServerBaseAddreess('10.26.01.2');

    expect(client.serverBaseAddress, '10.26.01.2');

    expect(client.announcedTopics.isEmpty, true);
    expect(client.lastAnnouncedValues.isEmpty, false);
  });
}
