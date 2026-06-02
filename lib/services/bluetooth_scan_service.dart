import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:speakify/models/slave_connection_type.dart';

/// Service that discovers nearby Bluetooth audio devices
/// and exposes them as a stream of [PeerDevice] objects.
///
/// Uses TWO discovery methods:
/// 1. **Bonded devices** — already-paired classic BT devices (neckbands, speakers, etc.)
/// 2. **BLE scan** — discovers BLE-advertising devices (modern speakers/headphones)
///
/// Most audio devices use classic Bluetooth (A2DP), NOT BLE.
/// So we rely primarily on bonded devices for audio device discovery.
class BluetoothScanService {
  // ── Stream setup ─────────────────────────────────────────────
  final StreamController<List<PeerDevice>> _deviceController =
      StreamController<List<PeerDevice>>.broadcast();

  /// The UI listens to this stream to get live device updates.
  Stream<List<PeerDevice>> get discoveredDevices => _deviceController.stream;

  // Deduplication map — keyed by MAC address.
  final Map<String, PeerDevice> _foundDevices = {};

  // Keep track of subscriptions so we can cancel them.
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  /// Whether Bluetooth is currently on.
  bool isBluetoothOn = false;

  /// Whether we're currently scanning.
  bool isScanning = false;

  // ── Start scanning ───────────────────────────────────────────

  /// Discover Bluetooth devices using both bonded devices + BLE scan.
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    // First, check if Bluetooth adapter is on.
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn = (state == BluetoothAdapterState.on);
    });

    // Wait a moment for the adapter state to be read.
    await Future.delayed(const Duration(milliseconds: 300));

    if (!isBluetoothOn) {
      debugPrint('BluetoothScanService: Bluetooth is OFF');
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('BluetoothScanService: Could not turn on Bluetooth: $e');
        return;
      }
    }

    _foundDevices.clear();
    isScanning = true;

    // ── Step 1: Get already-paired (bonded) classic BT devices ──
    // This is the PRIMARY way to find audio devices like neckbands,
    // speakers, and headphones. They use classic Bluetooth (A2DP),
    // which BLE scanning does NOT detect.
    try {
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      debugPrint('BluetoothScanService: Found ${bondedDevices.length} bonded devices');

      for (final device in bondedDevices) {
        final name = device.platformName;
        if (name.isEmpty) continue;

        final macAddress = device.remoteId.str;
        _foundDevices[macAddress] = PeerDevice(
          id: macAddress,
          name: name,
          connectionType: _guessDeviceTypeFromName(name),
          isConnected: false,
          latencyMs: null,
        );
        debugPrint('  Bonded: $name ($macAddress)');
      }

      // Push bonded devices to UI immediately.
      _emitDevices();
    } catch (e) {
      debugPrint('BluetoothScanService: Error getting bonded devices: $e');
    }

    // ── Step 2: BLE scan for additional devices ─────────────────
    // Some modern audio devices also advertise via BLE.
    // This catches any that aren't already paired.
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final deviceName = result.device.platformName;
          if (deviceName.isEmpty) continue;

          final macAddress = result.device.remoteId.str;
          // Don't overwrite bonded devices (they're higher priority).
          if (_foundDevices.containsKey(macAddress)) continue;

          _foundDevices[macAddress] = PeerDevice(
            id: macAddress,
            name: deviceName,
            connectionType: _guessDeviceTypeFromName(deviceName),
            isConnected: false,
            latencyMs: null,
          );
          debugPrint('  BLE discovered: $deviceName ($macAddress)');
        }
        _emitDevices();
      },
      onError: (error) {
        debugPrint('BluetoothScanService: BLE scan error: $error');
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.balanced,
      );
    } catch (e) {
      debugPrint('BluetoothScanService: BLE startScan failed: $e');
    }

    isScanning = false;
  }

  // ── Stop scanning ────────────────────────────────────────────

  /// Stop an ongoing BLE scan.
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('BluetoothScanService: stopScan failed: $e');
    }
    isScanning = false;
  }

  // ── Device type heuristic ────────────────────────────────────

  /// Guess whether a device is a speaker or headphones based on its name.
  SlaveConnectionType _guessDeviceTypeFromName(String name) {
    final lower = name.toLowerCase();

    // Common headphone/earbuds naming patterns
    if (lower.contains('headphone') ||
        lower.contains('buds') ||
        lower.contains('airpod') ||
        lower.contains('earbuds') ||
        lower.contains('earpod') ||
        lower.contains('freebuds') ||
        lower.contains('neckband') ||
        lower.contains('wh-') || // Sony WH- series headphones
        lower.contains('wf-') || // Sony WF- series earbuds
        lower.contains('earphone') ||
        lower.contains('pods') ||
        lower.contains('band')) {
      return SlaveConnectionType.bluetoothHeadphones;
    }

    // Default to speaker for other BT audio devices
    return SlaveConnectionType.bluetoothSpeaker;
  }

  // ── Helpers ──────────────────────────────────────────────────

  /// Push the current device list to the UI stream.
  void _emitDevices() {
    if (!_deviceController.isClosed) {
      _deviceController.add(_foundDevices.values.toList());
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────

  /// Dispose all subscriptions and close the stream controller.
  void dispose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    if (!_deviceController.isClosed) {
      _deviceController.close();
    }
    _foundDevices.clear();
  }
}