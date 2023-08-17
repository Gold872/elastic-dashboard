class IPAddressUtil {
  static bool isTeamNumber(String ipAddress) {
    return int.tryParse(ipAddress) != null;
  }

  static String teamNumberToIP(int teamNumber) {
    return '10.${teamNumber ~/ 100}.${teamNumber % 100}.2';
  }
}
