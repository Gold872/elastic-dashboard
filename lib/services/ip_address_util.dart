import 'dart:io';
import 'dart:typed_data';

class IPAddressUtil {
  static bool isTeamNumber(String ipAddress) {
    return int.tryParse(ipAddress) != null;
  }

  static String teamNumberToIP(int teamNumber) {
    return '10.${teamNumber ~/ 100}.${teamNumber % 100}.2';
  }

  static String getIpFromInt32Value(int value) =>
      InternetAddress.fromRawAddress(
              (ByteData(4)..setInt32(0, value)).buffer.asUint8List())
          .address;
}
