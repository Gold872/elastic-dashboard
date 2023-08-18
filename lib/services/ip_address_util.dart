import 'dart:io';
import 'dart:typed_data';

class IPAddressUtil {
  static bool isTeamNumber(String ipAddress) {
    return int.tryParse(ipAddress) != null;
  }

  static String teamNumberToIP(int teamNumber) {
    String te = (teamNumber ~/ 100).toString();
    String am = (teamNumber % 100).toString().padLeft(2, '0');

    return '10.$te.$am.2';
  }

  static String getIpFromInt32Value(int value) =>
      InternetAddress.fromRawAddress(
              (ByteData(4)..setInt32(0, value)).buffer.asUint8List())
          .address;
}
