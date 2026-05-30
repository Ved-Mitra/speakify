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
  State<DeviceListScreen> createState() => _DeviceListScreenState(role);
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  DeviceRole stateRole = DeviceRole.slave;
  bool _isConnected = true;

  _DeviceListScreenState(DeviceRole role) {
    stateRole = role;
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text('${stateRole.name} Mode'),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 15),
            if (_isConnected) DeviceList() else EmptyList(),
          ],
        ),
      ),
    );
  }
}

class EmptyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 24),
        Text('Searching for devices....', style: AppTextStyles.bodyLarge),
        Text(
          'Make Sure all devices are on the same Wi-Fi network',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class DeviceList extends StatefulWidget {
  List<PeerDevice> devices;
  DeviceList({super.key, required this.devices});

  @override
  State<DeviceList> createState() => _DeviceListState(devices);
}

class _DeviceListState extends State<DeviceList> {
  final List<PeerDevice> devices;
  _DeviceListState({required this.devices});

  @override
  Widget build (BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Text('Connected Devices', textAlign: TextAlign.left,),
          Text('${devices.where((d)=>d.isConnected).length}/${AppConstants.maxSlaveDevices}', textAlign: TextAlign.right,),
          ],
        ),
        ListView.builder(itemCount: devices.length, itemBuilder: DeviceBuilder()),
      ],
    )
  }
}


class DeviceBuilder extends StatelessWidget {
  final int id;
  final String name;
  final bool isConnected;
  final int latency;
  final IconData icon=Icons.phone_iphone_outlined;

  const DeviceBuilder({
    super.key,
    required this.id,
    required this.name,
    required this.isConnected,
    required this.latency,
  });

  @override
  Widget build (BuildContext context) {
    final Color accentColor= isConnected ? AppColors.success:AppColors.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // onTap: onTap,
        // splashColor controls the ripple color when you tap.
        splashColor: accentColor.withValues(alpha: 0.1),
        // highlightColor controls the sustained press color.
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
          // Fix 2: Row layout — Icon | Text Column | Spacer | Arrow
          child: Row(
            children: [
              // Left icon in a subtle circular container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 4),
                    Text('${latency}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(radius: 5, backgroundColor: accentColor),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}