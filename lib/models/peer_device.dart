/// Represents a peer device in the Speakify network.
class PeerDevice {
  /// Unique identifier for this device (typically MAC address or UUID).
  final String id;

  /// Human-readable device name (e.g., "Ved's Pixel 7").
  final String name;

  /// IP address of the device on the local network.
  final String? ipAddress;

  /// Whether this device is currently connected to the group.
  final bool isConnected;

  /// Ping latency to this device in milliseconds (null if not measured).
  final int? latencyMs;

  const PeerDevice({
    required this.id,
    required this.name,
    this.ipAddress,
    this.isConnected = false,
    this.latencyMs,
  });

  PeerDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    bool? isConnected,
    int? latencyMs,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  @override
  String toString() => 'PeerDevice($name, connected: $isConnected)';
}
