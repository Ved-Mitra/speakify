import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speakify/models/device_role.dart';
import 'package:speakify/models/slave_connection_type.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:speakify/utils/constants.dart';
import 'package:speakify/services/bluetooth_scan_service.dart';

class DeviceListScreen extends StatefulWidget {
  final DeviceRole role;
  const DeviceListScreen({super.key, required this.role});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  bool _isSearching = true;

  // ── Bluetooth scanning ─────────────────────────────────────
  late BluetoothScanService _btService;
  List<PeerDevice> _btDevices = [];
  StreamSubscription<List<PeerDevice>>? _btSubscription;

  // ── Mock Wi-Fi data (will be replaced in Phase 1, Step 3) ──
  final List<PeerDevice> _mockWifiDevices = [
    PeerDevice(
      id: '1',
      name: "Ved's Pixel 7",
      connectionType: SlaveConnectionType.wifi,
      isConnected: true,
      latencyMs: 12,
      ipAddress: '192.168.1.5',
    ),
    PeerDevice(
      id: '2',
      name: "Phone 2",
      connectionType: SlaveConnectionType.wifi,
      isConnected: true,
      latencyMs: 18,
      ipAddress: '192.168.1.8',
    ),
    PeerDevice(
      id: '3',
      name: "Phone 3",
      connectionType: SlaveConnectionType.wifi,
      isConnected: false,
    ),
  ];

  /// All devices combined (Wi-Fi mock + real BT scan results).
  List<PeerDevice> get _allDevices => [..._mockWifiDevices, ..._btDevices];

  @override
  void initState() {
    super.initState();

    // Initialize BT scanning service.
    _btService = BluetoothScanService();

    // Listen to discovered BT devices and update the UI.
    _btSubscription = _btService.discoveredDevices.listen((devices) {
      if (mounted) {
        setState(() {
          _btDevices = devices;
        });
      }
    });

    // Start scanning — runs async in the background.
    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() => _isSearching = true);

    // Start BT scan (runs for ~15 seconds).
    await _btService.startScan();

    // Once scan completes, hide the loading spinner.
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    _btService.dispose();
    super.dispose();
  }

  String get _roleTitle {
    final name = widget.role.name;
    return '${name[0].toUpperCase()}${name.substring(1)} Mode';
  }

  @override
  Widget build(BuildContext context) {
    // Show search state only if we have zero devices AND still scanning.
    // Once any device appears (even during scan), show the list.
    final showSearching = _isSearching && _allDevices.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text(_roleTitle),
        actions: [
          // Rescan button in the app bar.
          if (!_isSearching)
            IconButton(
              onPressed: _startScanning,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rescan',
            ),
          // Show a small spinner in the app bar while scanning.
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: showSearching
          ? const _EmptySearchState()
          : _DeviceListBody(
              devices: _allDevices,
              isMaster: widget.role == DeviceRole.master,
            ),
    );
  }
}

/// Shows a loading spinner while searching for devices.
class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Searching for devices...', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Scanning Wi-Fi network and Bluetooth...',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shows two sections: Wi-Fi Phones and Bluetooth Devices.
class _DeviceListBody extends StatelessWidget {
  final List<PeerDevice> devices;
  final bool isMaster;
  const _DeviceListBody({required this.devices, required this.isMaster});

  @override
  Widget build(BuildContext context) {
    final wifiDevices = devices.where((d) => d.isWifi).toList();
    final btDevices = devices.where((d) => d.isBluetooth).toList();
    final totalConnected = devices.where((d) => d.isConnected).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // ── Overall status ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('All Connected', style: AppTextStyles.titleLarge),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalConnected/${AppConstants.maxSlaveDevices}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Wi-Fi Phones Section ───────────────────────────────
        _SectionHeader(
          icon: Icons.wifi_rounded,
          title: 'Phones (Wi-Fi)',
          color: AppColors.primary,
          count: wifiDevices.where((d) => d.isConnected).length,
        ),
        const SizedBox(height: 8),
        ...wifiDevices.map((device) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceTile(device: device),
            )),

        const SizedBox(height: 20),

        // ── Bluetooth Devices Section ──────────────────────────
        _SectionHeader(
          icon: Icons.bluetooth_rounded,
          title: 'Bluetooth Devices',
          color: AppColors.secondary,
          count: btDevices.where((d) => d.isConnected).length,
        ),
        const SizedBox(height: 8),
        if (btDevices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Text(
              'No Bluetooth audio devices found.\nMake sure your speaker/headphones are in pairing mode.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
          ...btDevices.map((device) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceTile(device: device),
              )),

        // Only show on Master mode
        if (isMaster) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '⚠️  Bluetooth devices may have ~150ms extra latency.\n'
              'Wi-Fi phone playback will be delayed to stay in sync.',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.warning.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Section header with icon, title, and connected count.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: color),
          ),
          const Spacer(),
          Text(
            '$count connected',
            style: AppTextStyles.labelSmall.copyWith(
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single device tile — adapts icon based on connection type.
class _DeviceTile extends StatelessWidget {
  final PeerDevice device;
  const _DeviceTile({required this.device});

  IconData get _deviceIcon {
    switch (device.connectionType) {
      case SlaveConnectionType.wifi:
        return Icons.phone_iphone_outlined;
      case SlaveConnectionType.bluetoothSpeaker:
        return Icons.speaker_rounded;
      case SlaveConnectionType.bluetoothHeadphones:
        return Icons.headphones_rounded;
    }
  }

  String get _statusText {
    if (!device.isConnected) return 'Not connected';
    if (device.isBluetooth) {
      return '~${device.latencyMs ?? "?"}ms BT latency';
    }
    return '${device.latencyMs ?? "?"}ms latency';
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        device.isConnected ? AppColors.success : AppColors.textDisabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('Tapped device: ${device.name} (${device.connectionType.name})');
        },
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: const GradientBoxBorder(
              gradient: AppColors.cardGradient,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Device icon in a tinted container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_deviceIcon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Device name + latency/status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_statusText, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // Connection type badge + status dot
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Small badge showing connection type
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (device.isBluetooth
                              ? AppColors.secondary
                              : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      device.isBluetooth ? 'BT' : 'Wi-Fi',
                      style: AppTextStyles.labelSmall.copyWith(
                        color:
                            device.isBluetooth ? AppColors.secondary : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CircleAvatar(radius: 5, backgroundColor: accentColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}