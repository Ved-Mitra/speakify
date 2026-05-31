import 'package:flutter/material.dart';
import 'package:speakify/models/device_role.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:speakify/utils/constants.dart';

class DeviceListScreen extends StatefulWidget {
  final DeviceRole role;
  const DeviceListScreen({super.key, required this.role});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
  // FIX: Don't pass arguments to the State constructor.
  // Access widget fields via `widget.role` inside the State class.
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  bool _isSearching = true;

  // Mock data — will be replaced with real discovery in Phase 1.
  final List<PeerDevice> _mockDevices = [
    PeerDevice(id: '1', name: "Ved's Pixel 7", isConnected: true, latencyMs: 12),
    PeerDevice(id: '2', name: "Phone 2", isConnected: true, latencyMs: 18),
    PeerDevice(id: '3', name: "Phone 3", isConnected: false),
  ];

  @override
  void initState() {
    super.initState();
    // Simulate a 2-second search, then show device list.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  // FIX #2: Capitalize first letter of enum name for display.
  // `widget.role.name` returns "master" or "slave" (lowercase).
  // This helper capitalizes it to "Master" or "Slave".
  String get _roleTitle {
    final name = widget.role.name;
    return '${name[0].toUpperCase()}${name.substring(1)} Mode';
  }

  @override // FIX: Was missing @override annotation
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text(_roleTitle),
      ),
      // FIX: Use a Column with Expanded for the list area.
      // ListView has infinite height — if placed directly inside a Column
      // without Expanded, Flutter doesn't know how tall to make it → crash.
      body: _isSearching
          ? const _EmptySearchState()
          : _DeviceListBody(devices: _mockDevices),
    );
  }
}

/// Shows a loading spinner while searching for devices.
class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    // Center vertically + horizontally on the full screen body.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Shrink-wrap the column
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Searching for devices...', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Make sure all devices are on the same Wi-Fi network',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shows the connection count header + scrollable device list.
class _DeviceListBody extends StatelessWidget {
  final List<PeerDevice> devices;
  // FIX: Widget fields must always be `final`.
  const _DeviceListBody({required this.devices});

  @override
  Widget build(BuildContext context) {
    final connectedCount = devices.where((d) => d.isConnected).length;

    return Column(
      children: [
        // ── Connection count header ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Connected Devices', style: AppTextStyles.titleLarge),
              Text(
                '$connectedCount/${AppConstants.maxSlaveDevices}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // ── Device list ──────────────────────────────────────────
        // FIX: Wrap ListView.builder in Expanded so it knows how
        // much vertical space it can use inside this Column.
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: devices.length,
            // FIX: itemBuilder is a FUNCTION (context, index) => Widget,
            // not a widget instance. It gets called once per item.
            itemBuilder: (context, index) {
              final device = devices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceTile(device: device),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single device tile in the list.
class _DeviceTile extends StatelessWidget {
  final PeerDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
        device.isConnected ? AppColors.success : AppColors.textDisabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('Tapped device: ${device.name}');
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
              // Phone icon in a tinted container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.phone_iphone_outlined,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Device name + latency
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      device.isConnected
                          ? '${device.latencyMs ?? "?"}ms latency'
                          : 'Not connected',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              // Status dot (green = connected, grey = not)
              CircleAvatar(radius: 5, backgroundColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}