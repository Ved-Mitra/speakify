import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Platform channel helper to access Android's native Bluetooth APIs.
///
/// flutter_blue_plus only handles BLE. For classic Bluetooth operations
/// (checking A2DP connection state, etc.), we need platform channels.
class BluetoothPlatform {
  BluetoothPlatform._();

  static const _channel = MethodChannel('speakify/bluetooth');

  /// Check if a classic Bluetooth device is currently connected.
  /// [macAddress] is the device's MAC address (e.g., "AA:BB:CC:DD:EE:FF").
  static Future<bool> isDeviceConnected(String macAddress) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isDeviceConnected',
        {'address': macAddress},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('BluetoothPlatform: isDeviceConnected error: $e');
      return false;
    }
  }

  /// Get all devices currently connected via A2DP (audio output profile).
  /// Returns a list of maps with 'address' and 'name' keys.
  static Future<List<Map<String, String>>> getConnectedA2dpDevices() async {
    try {
      final result = await _channel.invokeListMethod<Map>(
        'getConnectedA2dpDevices',
      );
      if (result == null) return [];

      return result.map((item) {
        return {
          'address': (item['address'] as String?) ?? '',
          'name': (item['name'] as String?) ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      debugPrint('BluetoothPlatform: getConnectedA2dpDevices error: $e');
      return [];
    }
  }
}
