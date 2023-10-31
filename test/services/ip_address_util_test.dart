import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ip address util', () {
    expect(IPAddressUtil.isTeamNumber('353'), true);
    expect(IPAddressUtil.isTeamNumber('10.03.53.2'), false);

    expect(IPAddressUtil.teamNumberToIP(353), 'roboRIO-353-FRC.local');
    expect(IPAddressUtil.teamNumberToIP(2601), 'roboRIO-2601-FRC.local');
    expect(IPAddressUtil.teamNumberToIP(47), 'roboRIO-47-FRC.local');
    expect(IPAddressUtil.teamNumberToIP(101), 'roboRIO-101-FRC.local');
    expect(IPAddressUtil.teamNumberToIP(3015), 'roboRIO-3015-FRC.local');
    expect(IPAddressUtil.teamNumberToIP(12053), 'roboRIO-12053-FRC.local');

    expect(IPAddressUtil.getIpFromInt32Value(2130706433), '127.0.0.1');
    expect(IPAddressUtil.getIpFromInt32Value(167982338), '10.3.53.2');
  });
}
