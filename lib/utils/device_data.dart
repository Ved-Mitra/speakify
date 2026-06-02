import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceMetadata {
  final String name;
  final String id;

  DeviceMetadata({required this.name, required this.id});
}

Future<DeviceMetadata> getDeviceNameAndId() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String deviceName = "Unknown";
  String deviceId = "Unknown";

  try {
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // 'model' provides the user-facing device name (e.g., "Pixel 7 Pro")
      deviceName = androidInfo.model; 
      // 'id' is the hardware build ID or you can fallback to hardware details
      deviceId = androidInfo.id; 
      
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      // 'name' provides the user-assigned device name (e.g., "John's iPhone")
      deviceName = iosInfo.name; 
      // 'identifierForVendor' uniquely identifies the device for your vendor account
      deviceId = iosInfo.identifierForVendor ?? "Unknown iOS ID"; 
    }
  } catch (e) {
    debugPrint("Failed to get device info: $e");
  }

  return DeviceMetadata(name: deviceName, id: deviceId);
}