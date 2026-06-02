import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:speakify/utils/device_data.dart';
import 'package:speakify/widgets/toast.dart';

class WifiConnectionService {
  var port = 5354;
  late Future<String?> masterIp;
  late Map<String, Socket> connectedDevices;

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
      ServerSocket server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
      );
      masterIp = NetworkInfo().getWifiIP();
      debugPrint('Server started at port $port');

      server.listen((Socket client) {
        debugPrint('Client Connected at ${client.remoteAddress.address}');

        client.listen((List<int> data) {
          debugPrint('Message Received ${utf8.decode(data)}');

          String encoded = '${jsonEncode(message)}\n';
          client.write(encoded);
        });
      });
    } catch (e) {
      debugPrint('Error Starting TCP Sever $e');
    }
  }

  Future<void> disconnect() async {}

  Future<void> connectToServer() async {
    try {
      Socket socket = await Socket.connect(masterIp, port,timeout: Duration(seconds: 5));
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
      );
    } catch (e) {
      debugPrint('Unable to connect $e');
    }
  }

  Future<void> kickClient() async {}

  Future<void> stopServer() async {}

  void dispose() {}
}
