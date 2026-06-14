import 'package:permission_handler/permission_handler.dart';

/// Centralized permission handling for Speakify.
///
/// Android requires Location + Bluetooth + Nearby Devices permissions
/// for Wi-Fi scanning and Bluetooth device discovery.
class PermissionHelper {
  PermissionHelper._();

  /// Request all permissions needed for device discovery.
  /// Returns `true` if ALL are granted, `false` otherwise.
  static Future<bool> requestAllPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.microphone,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  /// Check current status of each permission without requesting.
  /// Returns a map of permission name → isGranted.
  static Future<Map<String, bool>> checkPermissions() async {
    final permissions = [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.microphone,
    ];

    final Map<String, bool> results = {};
    for (final perm in permissions) {
      final status = await perm.status;
      results[perm.toString()] = status.isGranted;
    }
    return results;
  }

  /// Check if any permission was permanently denied.
  /// If so, we must send the user to system Settings (can't request again).
  static Future<bool> isAnyPermanentlyDenied() async {
    final permissions = [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.microphone,
    ];

    for (final perm in permissions) {
      if (await perm.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// Open the app's system settings page.
  /// Use this when a permission is permanently denied — the user
  /// must manually toggle it from Settings since the OS won't show
  /// the permission dialog again.
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
