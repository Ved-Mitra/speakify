import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:speakify/models/slave_connection_type.dart';

/// Service that scans for nearby Bluetooth audio devices
/// and exposes them as a stream of [PeerDevice] objects.
class BluetoothScanService {
  // ── Stream setup ─────────────────────────────────────────────
  // A broadcast StreamController allows multiple widgets to listen.
  final StreamController<List<PeerDevice>> _deviceController =
      StreamController<List<PeerDevice>>.broadcast();

  /// The UI listens to this stream to get live device updates.
  Stream<List<PeerDevice>> get discoveredDevices => _deviceController.stream;

  // Deduplication map — keyed by MAC address (remoteId).
  final Map<String, PeerDevice> _foundDevices = {};

  // Keep track of scan subscription so we can cancel it.
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Track Bluetooth adapter state subscription.
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  /// Whether Bluetooth is currently on.
  bool isBluetoothOn = false;

  /// Whether we're currently scanning.
  bool isScanning = false;

  // ── Start scanning ───────────────────────────────────────────

  /// Begin scanning for nearby Bluetooth devices.
  /// Scans for [timeout] duration, then stops automatically.
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    // First, check if Bluetooth adapter is on.
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn = (state == BluetoothAdapterState.on);
    });

    // Wait a moment for the adapter state to be read.
    await Future.delayed(const Duration(milliseconds: 300));

    if (!isBluetoothOn) {
      debugPrint('BluetoothScanService: Bluetooth is OFF');
      // Try to turn it on (Android only — shows a system dialog).
      try {
        await FlutterBluePlus.turnOn();
        // Wait for it to turn on.
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint('BluetoothScanService: Could not turn on Bluetooth: $e');
        return;
      }
    }

    // Clear previous results.
    _foundDevices.clear();
    isScanning = true;

    // Listen to scan results.
    // FlutterBluePlus.scanResults emits a List<ScanResult> each time
    // a new device is found or an existing one is updated.
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          // Skip devices with no name (unnamed BT devices are usually
          // not audio devices and would clutter the list).
          final deviceName = result.device.platformName;
          if (deviceName.isEmpty) continue;

          // Convert to PeerDevice and deduplicate by MAC address.
          final macAddress = result.device.remoteId.str;
          _foundDevices[macAddress] = PeerDevice(
            id: macAddress,
            name: deviceName,
            connectionType: _guessDeviceType(result),
            isConnected: false,
            // RSSI can give rough distance indication, but not latency.
            // Actual latency depends on codec, measured later.
            latencyMs: null,
          );
        }

        // Push updated device list to the UI.
        if (!_deviceController.isClosed) {
          _deviceController.add(_foundDevices.values.toList());
        }
      },
      onError: (error) {
        debugPrint('BluetoothScanService: Scan error: $error');
      },
    );

    // Start the actual scan.
    // withServices: [] means scan for ALL devices (no filter).
    // androidScanMode is balanced between power and latency.
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.balanced,
      );
    } catch (e) {
      debugPrint('BluetoothScanService: startScan failed: $e');
    }

    isScanning = false;
  }

  // ── Stop scanning ────────────────────────────────────────────

  /// Stop an ongoing scan.
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
  ///
  /// This is a simple heuristic — in production you'd check the
  /// Bluetooth Class of Device (CoD) bits for more accuracy.
  SlaveConnectionType _guessDeviceType(ScanResult result) {
    final name = result.device.platformName.toLowerCase();

    // Common headphone naming patterns
    if (name.contains('headphone') ||
        name.contains('buds') ||
        name.contains('airpod') ||
        name.contains('earbuds') ||
        name.contains('wh-') || // Sony WH- series headphones
        name.contains('wf-') || // Sony WF- series earbuds
        name.contains('earpod') ||
        name.contains('freebuds')) {
      return SlaveConnectionType.bluetoothHeadphones;
    }

    // Default to speaker for other audio devices
    return SlaveConnectionType.bluetoothSpeaker;
  }

  // ── Cleanup ──────────────────────────────────────────────────

  /// Dispose all subscriptions and close the stream controller.
  /// Call this when the service is no longer needed.
  void dispose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    if (!_deviceController.isClosed) {
      _deviceController.close();
    }
    _foundDevices.clear();
  }
}