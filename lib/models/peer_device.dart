import 'slave_connection_type.dart';

/// Represents a peer device in the Speakify network.
///
/// Can be either a phone (Wi-Fi) or a Bluetooth audio device (speaker/headphones).
class PeerDevice {
  /// Unique identifier for this device (typically MAC address or UUID).
  final String id;

  /// Human-readable device name (e.g., "Ved's Pixel 7" or "JBL Flip 6").
  final String name;

  /// The type of connection this slave uses (Wi-Fi phone, BT speaker, BT headphones).
  final SlaveConnectionType connectionType;

  /// IP address of the device on the local network (only for Wi-Fi devices).
  final String? ipAddress;

  /// Whether this device is currently connected to the group.
  final bool isConnected;

  /// Ping latency to this device in milliseconds (null if not measured).
  /// For Bluetooth devices, this represents the estimated codec latency.
  final int? latencyMs;

  const PeerDevice({
    required this.id,
    required this.name,
    this.connectionType = SlaveConnectionType.wifi,
    this.ipAddress,
    this.isConnected = false,
    this.latencyMs,
  });

  /// Whether this is a Bluetooth audio device (speaker or headphones).
  bool get isBluetooth =>
      connectionType == SlaveConnectionType.bluetoothSpeaker ||
      connectionType == SlaveConnectionType.bluetoothHeadphones;

  /// Whether this is a Wi-Fi phone/tablet.
  bool get isWifi => connectionType == SlaveConnectionType.wifi;

  PeerDevice copyWith({
    String? id,
    String? name,
    SlaveConnectionType? connectionType,
    String? ipAddress,
    bool? isConnected,
    int? latencyMs,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  @override
  String toString() =>
      'PeerDevice($name, type: ${connectionType.name}, connected: $isConnected)';
}
