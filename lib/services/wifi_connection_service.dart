import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:speakify/models/slave_connection_type.dart';
import 'package:speakify/utils/device_data.dart';
import 'package:speakify/widgets/toast.dart';

/// Manages TCP socket connections for the Speakify control channel.
///
/// **Master mode**: Runs a TCP server that phone Slaves connect to.
/// **Slave mode**: Connects as a TCP client to the Master's IP.
///
/// Message protocol (JSON, newline-terminated):
/// - "handshake"     → Slave → Master (sends device info)
/// - "welcome"       → Master → Slave (acknowledges join)
/// - "device_joined" → Master → all Slaves (broadcasts new device)
/// - "device_left"   → Master → all Slaves (broadcasts disconnection)
/// - "ping"/"pong"   → for latency measurement (Phase 4)
class WifiConnectionService {
  final int _port = 5354;

  // ── Server-side state (Master) ──────────────────────────────
  ServerSocket? _server;
  final Map<String, Socket> _clients = {}; // deviceId → socket
  final List<PeerDevice> _connectedDevices = [];
  Timer? _pingTimer;

  // ── Client-side state (Slave) ───────────────────────────────
  Socket? _slaveSocket;
  bool _isConnectedToMaster = false;

  /// Notifier that fires whenever the Slave's connection to the Master changes.
  /// The Slave UI listens to this to update the connection badge reactively.
  final ValueNotifier<bool> masterConnectionNotifier = ValueNotifier(false);

  // ── Stream to notify UI of device list changes ──────────────
  final StreamController<List<PeerDevice>> _deviceStreamController = StreamController<List<PeerDevice>>.broadcast();

  /// UI listens to this stream to get live updates of connected Wi-Fi devices.
  Stream<List<PeerDevice>> get connectedDevicesStream => _deviceStreamController.stream;

  /// Current list of connected devices (for synchronous reads).
  List<PeerDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// Whether this device is connected to a Master (Slave mode).
  bool get isConnectedToMaster => _isConnectedToMaster;

  /// Whether the server is running (Master mode).
  bool get isServerRunning => _server != null;

  // ── Master's own IP ─────────────────────────────────────────
  String? _localIp;

  /// The local Wi-Fi IP address (available after startServer).
  String? get localIp => _localIp;

  //  MASTER MODE — TCP Server

  /// Start the TCP server. Call this in Master mode.
  Future<bool> startServer() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _localIp = await NetworkInfo().getWifiIP();
      debugPrint('Server started at $_localIp:$_port');

      // Listen for incoming client connections.
      // cancelOnError: false → keep accepting new clients even if one errors.
      _server!.listen(
        (Socket clientSocket) {
          debugPrint(
              'Client connected from ${clientSocket.remoteAddress.address}');
          _handleNewConnection(clientSocket);
        },
        onError: (e) => debugPrint('Server listen error: $e'),
        cancelOnError: false,
      );

      // Start periodic pings to measure network latency
      _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendPingsToAll());

      return true;
    } catch (e) {
      debugPrint('Error starting TCP server: $e');
      return false;
    }
  }

  /// Handle a newly connected client socket.
  void _handleNewConnection(Socket clientSocket) {
    bool handshakeDone = false;
    PeerDevice? clientDevice;
    // Buffer for accumulating partial messages (TCP stream boundary issue).
    String buffer = '';

    clientSocket.listen(
      (List<int> data) {
        // TCP data can arrive in chunks. Accumulate in buffer and split on newline.
        buffer += utf8.decode(data);
        final lines = buffer.split('\n');
        // Last element is either empty (complete message) or a partial message.
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          try {
            final message = jsonDecode(line) as Map<String, dynamic>;
            _processClientMessage(
              clientSocket,
              message,
              handshakeDone,
              clientDevice,
              (done) => handshakeDone = done,
              (device) => clientDevice = device,
            );
          } catch (e) {
            debugPrint('Failed to parse client message: $e');
          }
        }
      },
      onError: (e) {
        debugPrint('Client socket error: $e');
        _handleClientDisconnection(clientSocket, clientDevice);
      },
      onDone: () {
        _handleClientDisconnection(clientSocket, clientDevice);
      },
      cancelOnError: false,
    );
  }

  /// Process a parsed JSON message from a client.
  void _processClientMessage(
    Socket clientSocket,
    Map<String, dynamic> message,
    bool handshakeDone,
    PeerDevice? clientDevice,
    void Function(bool) setHandshakeDone,
    void Function(PeerDevice) setClientDevice,
  ) {
    final type = message['type'] as String?;

    if (type == 'handshake' && !handshakeDone) {
      setHandshakeDone(true);

      final deviceId = message['deviceId'] as String;
      final deviceName = message['deviceName'] as String;

      // Create the PeerDevice and register it.
      final device = PeerDevice(
        id: deviceId,
        name: deviceName,
        connectionType: SlaveConnectionType.wifi,
        isConnected: true,
        ipAddress: clientSocket.remoteAddress.address,
      );
      setClientDevice(device);

      _connectedDevices.add(device);
      _clients[deviceId] = clientSocket;
      _notifyDeviceListChanged();

      // Send "welcome" back to the new client.
      _sendMessage(clientSocket, {
        'type': 'welcome',
        'deviceName': deviceName,
        'deviceId': deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Broadcast "device_joined" to all OTHER connected clients.
      _broadcastToAll({
        'type': 'device_joined',
        'deviceName': deviceName,
        'deviceId': deviceId,
      }, excludeId: deviceId);

      showToast('$deviceName connected');
      debugPrint('Handshake complete with $deviceName ($deviceId)');
    } else if (type == 'pong') {
      final int sentTime = message['timestamp'] as int;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int rtt = now - sentTime;
      final int latency = rtt ~/ 2;

      // Update the device's latency property and notify UI
      if (clientDevice != null) {
        final index = _connectedDevices.indexWhere((d) => d.id == clientDevice.id);
        if (index != -1) {
          _connectedDevices[index] = _connectedDevices[index].copyWith(latencyMs: latency);
          _notifyDeviceListChanged();
        }
      }
    }
  }

  /// Handle a client disconnection (either error or graceful close).
  void _handleClientDisconnection(Socket clientSocket, PeerDevice? device) {
    try {
      clientSocket.destroy();
    } catch (_) {}

    if (device != null) {
      _connectedDevices.removeWhere((d) => d.id == device.id);
      _clients.remove(device.id);
      _notifyDeviceListChanged();

      // Broadcast "device_left" to remaining clients.
      _broadcastToAll({
        'type': 'device_left',
        'deviceName': device.name,
        'deviceId': device.id,
      });

      showToast('${device.name} disconnected');
      debugPrint('Client disconnected: ${device.name}');
    }
  }

  /// Kick a specific client by ID.
  Future<void> kickClient(String deviceId) async {
    final socket = _clients[deviceId];
    if (socket != null) {
      try {
        socket.destroy();
      } catch (_) {}
      _clients.remove(deviceId);
    }
    final device = _connectedDevices.where((d) => d.id == deviceId).firstOrNull;
    _connectedDevices.removeWhere((d) => d.id == deviceId);
    _notifyDeviceListChanged();

    if (device != null) {
      _broadcastToAll({
        'type': 'device_left',
        'deviceName': device.name,
        'deviceId': device.id,
      });
      showToast('${device.name} removed');
    }
  }

  /// Stop the TCP server and disconnect all clients.
  Future<void> stopServer() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final client in _clients.values) {
      try {
        client.destroy();
      } catch (_) {}
    }
    _clients.clear();
    _connectedDevices.clear();
    _notifyDeviceListChanged();

    // Close the server socket.
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;

    debugPrint('Server stopped');
  }

  //  SLAVE MODE — TCP Client

  /// Connect to the Master's server. Call this in Slave mode.
  /// [masterIp] is the IP address entered by the user.
  /// Returns `true` if connected and handshake succeeded.
  Future<bool> connectToMaster(String masterIp) async {
    try {
      _slaveSocket = await Socket.connect(
        masterIp,
        _port,
        timeout: const Duration(seconds: 5),
      );
      debugPrint(
          'Connected to Master: ${_slaveSocket!.remoteAddress.address}:${_slaveSocket!.remotePort}');

      // Get this device's info for the handshake.
      final deviceData = await getDeviceNameAndId();

      // Send handshake (newline-terminated JSON).
      _sendMessage(_slaveSocket!, {
        'type': 'handshake',
        'deviceId': deviceData.id,
        'deviceName': deviceData.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Listen for messages from the Master.
      String buffer = '';
      _slaveSocket!.listen(
        (List<int> data) {
          buffer += utf8.decode(data);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final message = jsonDecode(line) as Map<String, dynamic>;
              _handleMasterMessage(message);
            } catch (e) {
              debugPrint('Failed to parse Master message: $e');
            }
          }
        },
        onError: (e) {
          debugPrint('Connection error: $e');
          _isConnectedToMaster = false;
          masterConnectionNotifier.value = false;
          showToast('Connection lost');
        },
        onDone: () {
          debugPrint('Server closed the connection');
          _isConnectedToMaster = false;
          masterConnectionNotifier.value = false;
          showToast('Disconnected from Master');
          try {
            _slaveSocket?.destroy();
          } catch (_) {}
          _slaveSocket = null;
        },
        cancelOnError: false,
      );

      _isConnectedToMaster = true;
      masterConnectionNotifier.value = true;
      return true;
    } catch (e) {
      debugPrint('Unable to connect to Master: $e');
      showToast('Connection failed');
      return false;
    }
  }

  /// Handle a message received from the Master (Slave side).
  void _handleMasterMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    switch (type) {
      case 'welcome':
        showToast('Joined group');
        debugPrint('Welcome received from Master');
        break;
      case 'device_joined':
        showToast('${message["deviceName"]} joined');
        break;
      case 'device_left':
        showToast('${message["deviceName"]} left');
        break;
      case 'ping':
        if (_slaveSocket != null) {
          _sendMessage(_slaveSocket!, {
            'type': 'pong',
            'timestamp': message['timestamp'],
          });
        }
        break;
      default:
        debugPrint('Unknown message type: $type');
    }
  }

  /// Disconnect from the Master (Slave mode).
  Future<void> disconnectFromMaster() async {
    _isConnectedToMaster = false;
    try {
      _slaveSocket?.destroy();
    } catch (_) {}
    _slaveSocket = null;
    debugPrint('Disconnected from Master');
  }

  //  SHARED HELPERS

  /// Send a JSON message to a socket (newline-terminated).
  void _sendMessage(Socket socket, Map<String, dynamic> message) {
    try {
      final encoded = '${jsonEncode(message)}\n';
      socket.write(encoded);
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  /// Broadcast a message to all connected clients, optionally excluding one.
  void _broadcastToAll(Map<String, dynamic> message, {String? excludeId}) {
    for (final entry in _clients.entries) {
      if (entry.key != excludeId) {
        _sendMessage(entry.value, message);
      }
    }
  }

  /// Sends a ping to all connected clients to measure latency.
  void _sendPingsToAll() {
    if (_clients.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _broadcastToAll({
      'type': 'ping',
      'timestamp': now,
    });
  }

  /// Helper to push a fresh copy of the connected devices list to the stream.
  void _notifyDeviceListChanged() {
    if (!_deviceStreamController.isClosed) {
      _deviceStreamController.add(List.from(_connectedDevices));
    }
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    // Close slave socket if connected.
    try {
      _slaveSocket?.destroy();
    } catch (_) {}

    // Close all client sockets and server.
    for (final socket in _clients.values) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _clients.clear();
    _connectedDevices.clear();

    try {
      await _server?.close();
    } catch (_) {}
    _server = null;

    if (!_deviceStreamController.isClosed) {
      _deviceStreamController.close();
    }
  }
}
