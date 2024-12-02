import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> transferFile(String localFilePath, String remoteFilePath) async {
  SharedPreferences perfs = await SharedPreferences.getInstance();
  int? teamNumber = perfs.getInt(PrefKeys.teamNumber);

  String host = IPAddressUtil.teamNumberToIP(teamNumber ?? Defaults.teamNumber);

  const int port = 22;
  const String username = 'lvuser';
  const String password = '';

  // Connect to the SSH server
  final client = SSHClient(
    await SSHSocket.connect(host, port),
    username: username,
    onPasswordRequest: () => password,
  );

  try {
    // Open an SFTP session
    final sftp = await client.sftp();

    // Create necessary directories for the remote file path
    await _createRemoteDirectories(sftp, remoteFilePath);

    // Open the remote file for writing
    final remoteFile = await sftp.open(
      remoteFilePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );

    // Stream the local file's contents to the remote file
    final fileStream = File(localFilePath)
        .openRead()
        .map((chunk) => Uint8List.fromList(chunk));
    final writer = await remoteFile.write(fileStream);

    await writer.done;
  } catch (e) {
    rethrow;
  } finally {
    client.close();
  }
}

Future<void> _createRemoteDirectories(
    SftpClient sftp, String remoteFilePath) async {
  final parts = remoteFilePath.split('/');
  parts.removeLast(); // Remove the file name

  String currentPath = '';
  for (final part in parts) {
    if (part.isEmpty) continue; // Skip empty parts caused by leading slashes
    currentPath += '/$part';
    try {
      // Check if the directory exists
      await sftp.stat(currentPath);
    } catch (e) {
      // If the directory does not exist, create it
      await sftp.mkdir(currentPath);
    }
  }
}

Future<String> loadFile(String remoteFilePath) async {
  SharedPreferences perfs = await SharedPreferences.getInstance();
  int? teamNumber = perfs.getInt(PrefKeys.teamNumber);

  String host = IPAddressUtil.teamNumberToIP(teamNumber ?? Defaults.teamNumber);

  const int port = 22;
  const String username = 'lvuser';
  const String password = '';

  // Connect to the SSH server
  final client = SSHClient(
    await SSHSocket.connect(host, port),
    username: username,
    onPasswordRequest: () => password,
  );

  try {
    // Open an SFTP session
    final sftp = await client.sftp();

    // Open the remote file for reading
    final remoteFile = await sftp.open(
      remoteFilePath,
      mode: SftpFileOpenMode.read,
    );

    // Read the file's contents
    final contents = await remoteFile.readBytes();
    return String.fromCharCodes(contents);
  } catch (e) {
    rethrow;
  } finally {
    client.close();
  }
}

Future<void> transferStringToFile(String content, String remoteFilePath) async {
  SharedPreferences perfs = await SharedPreferences.getInstance();
  int? teamNumber = perfs.getInt(PrefKeys.teamNumber);

  String host = IPAddressUtil.teamNumberToIP(teamNumber ?? Defaults.teamNumber);

  const int port = 22;
  const String username = 'lvuser';
  const String password = '';

  // Connect to the SSH server
  final client = SSHClient(
    await SSHSocket.connect(host, port),
    username: username,
    onPasswordRequest: () => password,
  );

  try {
    // Open an SFTP session
    final sftp = await client.sftp();

    // Create necessary directories for the remote file path
    await _createRemoteDirectories(sftp, remoteFilePath);

    // Open the remote file for writing
    final remoteFile = await sftp.open(
      remoteFilePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );

    // Stream the local file's contents to the remote file
    Stream<Uint8List> stream =
        Stream.fromIterable([Uint8List.fromList(content.codeUnits)]);
    final writer = await remoteFile.write(stream);

    await writer.done;
  } catch (e) {
    rethrow;
  } finally {
    client.close();
  }
}
