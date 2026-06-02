import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speakify/models/device_role.dart';
import 'package:speakify/models/slave_connection_type.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:speakify/utils/constants.dart';
import 'package:speakify/services/bluetooth_scan_service.dart';
import 'package:speakify/services/wifi_connection_service.dart';

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

  // ── Wi-Fi connection service ───────────────────────────────
  late WifiConnectionService _wifiService;
  List<PeerDevice> _wifiDevices = [];
  StreamSubscription<List<PeerDevice>>? _wifiSubscription;

  // ── Slave mode: IP input ───────────────────────────────────
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;

  /// All devices combined (real Wi-Fi + real BT scan results).
  List<PeerDevice> get _allDevices => [..._wifiDevices, ..._btDevices];

  @override
  void initState() {
    super.initState();

    // ── Bluetooth scanning ────────────────────────────────────
    _btService = BluetoothScanService();
    _btSubscription = _btService.discoveredDevices.listen((devices) {
      if (mounted) setState(() => _btDevices = devices);
    });

    // ── Wi-Fi connection service ──────────────────────────────
    _wifiService = WifiConnectionService();
    _wifiSubscription = _wifiService.connectedDevicesStream.listen((devices) {
      if (mounted) setState(() => _wifiDevices = devices);
    });

    // Start scanning / server based on role.
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isSearching = true);

    // Start BT scan (both Master and Slave can see BT devices).
    _btService.startScan();

    // Master: start the TCP server.
    if (widget.role == DeviceRole.master) {
      await _wifiService.startServer();
      // Force a rebuild to show the IP address.
      if (mounted) setState(() {});
    }

    // Wait for BT scan to produce some results, then hide spinner.
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _rescan() async {
    setState(() => _isSearching = true);
    _btService.stopScan();
    await _btService.startScan();
    if (mounted) setState(() => _isSearching = false);
  }

  /// Slave mode: connect to the Master's IP.
  Future<void> _connectToMaster() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() => _isConnecting = true);
    final success = await _wifiService.connectToMaster(ip);
    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        // Clear the text field after successful connection.
        _ipController.clear();
      }
    }
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    _btService.dispose();
    _wifiSubscription?.cancel();
    _wifiService.dispose();
    _ipController.dispose();
    super.dispose();
  }

  String get _roleTitle {
    final name = widget.role.name;
    return '${name[0].toUpperCase()}${name.substring(1)} Mode';
  }

  @override
  Widget build(BuildContext context) {
    final showSearching = _isSearching && _allDevices.isEmpty;
    final isMaster = widget.role == DeviceRole.master;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text(_roleTitle),
        actions: [
          if (!_isSearching)
            IconButton(
              onPressed: _rescan,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rescan',
            ),
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
              isMaster: isMaster,
              masterIp: isMaster ? _wifiService.localIp : null,
              slaveIpController: !isMaster ? _ipController : null,
              isConnecting: _isConnecting,
              isConnectedToMaster: _wifiService.isConnectedToMaster,
              onConnect: !isMaster ? _connectToMaster : null,
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
/// Also shows Master IP or Slave IP input depending on the role.
class _DeviceListBody extends StatelessWidget {
  final List<PeerDevice> devices;
  final bool isMaster;
  final String? masterIp;
  final TextEditingController? slaveIpController;
  final bool isConnecting;
  final bool isConnectedToMaster;
  final VoidCallback? onConnect;

  const _DeviceListBody({
    required this.devices,
    required this.isMaster,
    this.masterIp,
    this.slaveIpController,
    this.isConnecting = false,
    this.isConnectedToMaster = false,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final wifiDevices = devices.where((d) => d.isWifi).toList();
    final btDevices = devices.where((d) => d.isBluetooth).toList();
    final totalConnected = devices.where((d) => d.isConnected).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // ── Master: Show IP address ────────────────────────────
        if (isMaster && masterIp != null)
          _MasterIpBanner(ip: masterIp!),

        // ── Slave: Show IP input + Connect button ──────────────
        if (!isMaster)
          _SlaveConnectCard(
            controller: slaveIpController!,
            isConnecting: isConnecting,
            isConnected: isConnectedToMaster,
            onConnect: onConnect!,
          ),

        const SizedBox(height: 12),

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
        if (wifiDevices.isEmpty && isMaster)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Text(
              'Waiting for phone slaves to connect...\nShare your IP address with other devices.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
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

/// Banner showing the Master's IP address for Slaves to connect to.
class _MasterIpBanner extends StatelessWidget {
  final String ip;
  const _MasterIpBanner({required this.ip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your IP Address', style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(
                  ip,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share this with other devices to connect',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card with an IP text field and Connect button for Slave mode.
class _SlaveConnectCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onConnect;

  const _SlaveConnectCard({
    required this.controller,
    required this.isConnecting,
    required this.isConnected,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle_rounded : Icons.wifi_rounded,
                color: isConnected ? AppColors.success : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Connected to Master' : 'Connect to Master',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isConnected ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          if (!isConnected) ...[
            const SizedBox(height: 12),
            // IP input field
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Enter Master IP (e.g., 192.168.1.5)',
                hintStyle: AppTextStyles.bodySmall,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Connect button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnecting ? null : onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Connect',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
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