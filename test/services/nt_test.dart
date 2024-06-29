import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';

void main() {
  test('NT4 Client', () {
    NTConnection ntConnection = NTConnection('10.3.5.32');

    expect(ntConnection.isNT4Connected, false);

    // Subscribing
    NT4Subscription subscription1 =
        ntConnection.subscribe('/SmartDashboard/Test Number');

    expect(ntConnection.subscriptions.length, greaterThanOrEqualTo(1));

    expect(ntConnection.getLastAnnouncedValue('/SmartDashboard/Test Number'),
        isNull);

    // Publishing and adding to the last announced values
    ntConnection.updateDataFromSubscription(subscription1, 3.53);

    expect(ntConnection.getLastAnnouncedValue('/SmartDashboard/Test Number'),
        isNull);

    ntConnection.updateDataFromTopic(
        NT4Topic(
            name: '/SmartDashboard/Test Number',
            type: NT4TypeStr.kFloat32,
            properties: {}),
        3.53);

    expect(ntConnection.getLastAnnouncedValue('/SmartDashboard/Test Number'),
        3.53);

    expect(subscription1.currentValue != null, true);

    NT4Subscription subscription2 =
        ntConnection.subscribe('/SmartDashboard/Test Number');

    // If the subscriptions are shared
    expect(ntConnection.subscriptions.length, 1);

    ntConnection.unSubscribe(subscription1);

    expect(ntConnection.subscriptions.length, 1);

    ntConnection.unSubscribe(subscription2);

    expect(ntConnection.subscriptions.length, 0);

    // Changing ip address
    expect(ntConnection.getLastAnnouncedValue('/SmartDashboard/Test Number'),
        3.53);

    ntConnection.changeIPAddress('10.30.15.2');

    expect(ntConnection.serverBaseAddress, '10.30.15.2');

    expect(ntConnection.announcedTopics().length, 0);
    expect(ntConnection.getLastAnnouncedValue('/SmartDashboard/Test Number'),
        3.53);
  });
}
