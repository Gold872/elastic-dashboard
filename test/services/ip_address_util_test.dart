import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';

void main() {
  test('ip address util', () {
    expect(IPAddressUtil.isTeamNumber('353'), true);
    expect(IPAddressUtil.isTeamNumber('10.03.53.2'), false);

    expect(IPAddressUtil.teamNumberToRIOmDNS(353), 'roboRIO-353-FRC.local');
    expect(IPAddressUtil.teamNumberToRIOmDNS(2601), 'roboRIO-2601-FRC.local');
    expect(IPAddressUtil.teamNumberToRIOmDNS(47), 'roboRIO-47-FRC.local');
    expect(IPAddressUtil.teamNumberToRIOmDNS(101), 'roboRIO-101-FRC.local');
    expect(IPAddressUtil.teamNumberToRIOmDNS(3015), 'roboRIO-3015-FRC.local');
    expect(IPAddressUtil.teamNumberToRIOmDNS(12053), 'roboRIO-12053-FRC.local');

    expect(IPAddressUtil.teamNumberToIP(353), '10.3.53.2');
    expect(IPAddressUtil.teamNumberToIP(2601), '10.26.01.2');
    expect(IPAddressUtil.teamNumberToIP(47), '10.0.47.2');
    expect(IPAddressUtil.teamNumberToIP(101), '10.1.01.2');
    expect(IPAddressUtil.teamNumberToIP(3015), '10.30.15.2');
    expect(IPAddressUtil.teamNumberToIP(12053), '10.120.53.2');

    expect(IPAddressUtil.getIpFromInt32Value(2130706433), '127.0.0.1');
    expect(IPAddressUtil.getIpFromInt32Value(167982338), '10.3.53.2');
  });
}
