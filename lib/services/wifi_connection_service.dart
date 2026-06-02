import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:speakify/utils/device_data.dart';
import 'package:speakify/widgets/toast.dart';

class WifiConnectionService {
  late ServerSocket _server;
  final int _port = 5354;
  late Future<String?> _masterIp;
  final List<PeerDevice> _connectedDevices = [];
  late Map<String, Socket> _client; //id-->socket

  //   Map<String, dynamic> message = {
  //     "type": "handshake",
  //     "deviceId": "unique_id",
  //     "deviceName": "ved's iPhone",
  //     "timestamp": DateTime.now().millisecondsSinceEpoch,
  //   };
  // Message types:
  // 1. "handshake"    — Slave sends its info to Master
  // 2. "welcome"      — Master acknowledges and sends group info
  // 3. "device_joined" — Master broadcasts to all slaves when a new device joins
  // 4. "device_left"   — Master broadcasts when a device disconnects
  // 5. "ping"/"pong"   — for latency measurement (Phase 4)

  Future<void> startServer() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _masterIp = NetworkInfo().getWifiIP();
      debugPrint('Server started at port $_port');

      _server.listen((Socket client) {
        debugPrint('Client Connected at ${client.remoteAddress.address}');
        __handleNewConnection(client);
      }, cancelOnError: true);
    } catch (e) {
      debugPrint('Error Starting TCP Sever $e');
    }
  }

  void __handleNewConnection(Socket clientSocket) {
    bool isHandShakeDone = false;
    PeerDevice? currentDevice;

    clientSocket.listen(
      (List<int> data) {
        String clientMessage = utf8.decode(data);
        Map<String, dynamic> message = jsonDecode(clientMessage);

        if (message["type"] == "handshake" && !isHandShakeDone) {
          isHandShakeDone = true;
          Map<String, dynamic> serverMessage = {
            "type": "welcome",
            "deviceName": message["deviceName"],
            "deviceId": message["deviceId"],
            "timestamp": DateTime.now().millisecondsSinceEpoch,
          };

          currentDevice = PeerDevice(
            id: message["deviceId"],
            name: message["deviceName"],
          );
          _connectedDevices.add(currentDevice!);
          _client[message["deviceId"]] = clientSocket;

          String encoded = jsonEncode(serverMessage);
          clientSocket.write(encoded);
        } else {
          _handleOngoingConnection(clientSocket);
        }
      },
      onError: (e) {
        debugPrint('Error : $e');
      },
      onDone: () {
        _handleDisconnection(clientSocket, currentDevice);
      },
      cancelOnError: true,
    );
  }

  void _handleOngoingConnection(Socket clientSocket) {}

  void _handleDisconnection(Socket clientSocket, PeerDevice? clientDevice) {
    clientSocket.close();

    if (clientDevice != null) {
      _connectedDevices.removeWhere((device) => device.id == clientDevice.id);
      showToast('${clientDevice.name} disconnected');
    }
  }

  Future<void> connectToServer() async {
    try {
      Socket socket = await Socket.connect(
        _masterIp,
        _port,
        timeout: Duration(seconds: 5),
      );
      debugPrint(
        'Connected to: ${socket.remoteAddress.address}:${socket.remotePort}',
      );

      DeviceMetadata deviceData = await getDeviceNameAndId();

      // sending handshake
      Map<String, dynamic> message = {
        "type": "handshake",
        "deviceId": deviceData.id,
        "deviceName": deviceData.name,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };
      String encodedHandshake = jsonEncode(message);
      socket.write(encodedHandshake);

      socket.listen(
        (List<int> data) {
          String serverMessage = utf8.decode(data);
          Map<String, dynamic> parsedJson = jsonDecode(serverMessage);
          if (parsedJson["type"] == "welcome") {
            showToast("Joined Group");
          }
          if (parsedJson["type"] == "device_joined") {
            showToast("${parsedJson["deviceName"]} joined");
          }
          if (parsedJson["type"] == "device_left") {
            showToast("${parsedJson["deviceName"]} left");
          }
        },
        onError: (e) {
          debugPrint('Error occured in slave $e');
        },
        onDone: () {
          debugPrint('Server closed the connection');
          socket.close();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Unable to connect $e');
    }
  }

  Future<void> disconnect(String id) async {
    
  }

  Future<void> kickClient(String id) async {
    _client[id]!.close();
    _connectedDevices.removeWhere((device) => device.id == id);
    showToast('Device removed');
  }

  Future<void> stopServer() async {
    for (var client in _client.entries) {
      client.value.close();
    }
    _connectedDevices.clear();
    _client.clear();
    await _server.close();
  }

  Future<void> dispose() async {
    for (var client in _client.entries) {
      client.value.close();
    }
    _client.clear();
    await _server.close();
  }
}
