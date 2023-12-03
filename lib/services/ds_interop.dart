import 'dart:convert';
import 'dart:io';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:flutter/foundation.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;

  Function()? onConnect;
  Function()? onDisconnect;

  Function(String ip)? onNewIPAnnounced;
  Function(bool isDocked)? onDriverStationDockChanged;

  Socket? _socket;
  ServerSocket? _dbModeServer;

  List<int> _tcpBuffer = [];

  String? _lastAnnouncedIP;
  bool _driverStationDocked = false;

  String? get lastAnnouncedIP => _lastAnnouncedIP;
  bool get driverStationDocked => _driverStationDocked;

  DSInteropClient({
    this.onNewIPAnnounced,
    this.onDriverStationDockChanged,
    this.onConnect,
    this.onDisconnect,
  }) {
    _connect();
  }

  void _connect() async {
    try {
      _socket = await Socket.connect(serverBaseAddress, 1742);
      _dbModeServer = await ServerSocket.bind(serverBaseAddress, 1741);
    } catch (e) {
      logger.debug(
          '[DS INTEROP] Failed to connect, attempting to reconnect in 5 seconds.');
      Future.delayed(const Duration(seconds: 5), _connect);
      return;
    }

    _socket!.listen(
      (data) {
        if (onConnect != null && !_serverConnectionActive) {
          _serverConnectionActive = true;
          onConnect?.call();
        }
        _tcpSocketOnMessage(utf8.decode(data));
      },
      onDone: _socketClose,
    );

    _dbModeServer!.listen(
      (socket) {
        socket.listen(
          (data) {
            _tcpServerOnMessage(data);
          },
        );
      },
      onDone: _socketClose,
    );
  }

  void _tcpSocketOnMessage(String data) {
    var jsonData = jsonDecode(data.toString());

    if (jsonData is! Map) {
      logger.warning('[DS INTEROP] Ignoring text message, not a Json Object');
      return;
    }

    var rawIP = jsonData['robotIP'];

    if (rawIP == null || rawIP == 0) {
      logger
          .warning('[DS INTEROP] Ignoring Json message, robot IP is not valid');
      return;
    }

    String ipAddress = IPAddressUtil.getIpFromInt32Value(rawIP);

    if (_lastAnnouncedIP != ipAddress) {
      onNewIPAnnounced?.call(ipAddress);
    }
    _lastAnnouncedIP = ipAddress;
  }

  void _tcpServerOnMessage(Uint8List data) {
    _tcpBuffer.addAll(data);
    Map<int, Uint8List> mappedData = {};

    int sublistIndex = 0;

    for (int i = 0; i < _tcpBuffer.length - 1;) {
      int size = (_tcpBuffer[i] << 8) | _tcpBuffer[i + 1];

      if (i >= _tcpBuffer.length - 1 - size || size == 0) {
        break;
      }

      Uint8List sublist =
          Uint8List.fromList(_tcpBuffer.sublist(i + 2, i + 2 + size));
      int tagID = sublist[0];
      mappedData[tagID] = sublist.sublist(1);

      sublistIndex = i + size + 2;

      i += size + 2;
    }

    _tcpBuffer = _tcpBuffer.sublist(sublistIndex);

    if (mappedData.containsKey(0x09)) {
      bool docked = (mappedData[0x09]![0] & 0x04 != 0);
      _driverStationDocked = docked;

      onDriverStationDockChanged?.call(docked);
    }
  }

  void _socketClose() {
    _socket?.close();
    _socket = null;

    _dbModeServer?.close();
    _dbModeServer = null;

    _serverConnectionActive = false;

    _driverStationDocked = false;
    onDriverStationDockChanged?.call(false);
    onDisconnect?.call();

    if (kDebugMode) {
      print(
          '[DS INTEROP] Connection closed, attempting to reconnect in 5 seconds.');
    }
    Future.delayed(const Duration(seconds: 5), _connect);
  }
}
