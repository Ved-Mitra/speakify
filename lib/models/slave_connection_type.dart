/// The type of connection a slave device uses.
enum SlaveConnectionType {
  /// A phone/tablet connected over Wi-Fi (full sync control).
  wifi,

  /// A Bluetooth speaker connected via A2DP (limited sync control).
  bluetoothSpeaker,

  /// Bluetooth headphones connected via A2DP (limited sync control).
  bluetoothHeadphones,
}
