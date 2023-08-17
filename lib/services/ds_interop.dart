import 'dart:convert';
import 'dart:io';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:flutter/foundation.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;

  Function()? onConnect;
  Function()? onDisconnect;

  Function(String ip)? onNewIPAnnounced;

  String? lastAnnouncedIP;
  Socket? _socket;

  DSInteropClient({this.onNewIPAnnounced, this.onConnect, this.onDisconnect}) {
    _connect();
  }

  void _connect() async {
    try {
      _socket = await Socket.connect(serverBaseAddress, 1742);
    } catch (e) {
      if (kDebugMode) {
        print(
            '[DS INTEROP] Failed to connect, attempting to reconnect in 5 seconds.');
      }
      Future.delayed(const Duration(seconds: 5), _connect);
      return;
    }

    _socket!.listen(
      (data) {
        if (onConnect != null && !_serverConnectionActive) {
          _serverConnectionActive = true;
          onConnect?.call();
        }
        _socketOnMessage(utf8.decode(data));
      },
      onDone: _socketClose,
    );
  }

  void _socketOnMessage(String data) {
    var jsonData = jsonDecode(data.toString());

    if (jsonData is! Map) {
      if (kDebugMode) {
        print('[DS INTEROP] Ignoring text message, not a Json Object');
      }
      return;
    }

    var rawIP = jsonData['robotIP'];

    if (rawIP == null || rawIP == 0) {
      if (kDebugMode) {
        print('[DS INTEROP] Ignoring Json message, robot IP is not valid');
      }
      return;
    }

    String ipAddress = IPAddressUtil.getIpFromInt32Value(rawIP);

    if (lastAnnouncedIP != ipAddress) {
      onNewIPAnnounced?.call(ipAddress);
    }
    lastAnnouncedIP = ipAddress;
  }

  void _socketClose() {
    _socket?.close();
    _socket = null;

    _serverConnectionActive = false;

    onDisconnect?.call();

    if (kDebugMode) {
      print(
          '[DS INTEROP] Connection closed, attempting to reconnect in 5 seconds.');
    }
    Future.delayed(const Duration(seconds: 5), _connect);
  }
}
