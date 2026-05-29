import 'package:flutter/material.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/theme/app_colors.dart';
import 'package:speakify/utils/constants.dart';
import 'package:gradient_borders/gradient_borders.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: true,
      right: true,
      top: true,
      bottom: true,
      minimum: EdgeInsets.all(24),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.speaker_group_rounded,
              size: 35,
              color: AppColors.primary,
            ),
            onPressed: () {
              // TODO: The Speaker icons rotates
            },
          ),
          title: Align(
            alignment: AlignmentGeometry.centerLeft,
            child: Text(
              AppConstants.appName,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 32
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 15),
            Text(
              AppConstants.appDes,
              style: AppTextStyles.headlineMedium
            ),
            SizedBox(height: 16),
            MasterDevice(),
            SizedBox(height: 16),
            SlaveDevices(),
            Spacer(),
            FootNote()
          ],
        ),
      ),
    );
  }
}

class MasterDevice extends StatefulWidget {
  const MasterDevice({super.key});

  @override
  State<MasterDevice> createState() => _MasterDevice();
}

class _MasterDevice extends State<MasterDevice> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: const GradientBoxBorder(
          gradient: AppColors.cardGradient,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.cell_tower_rounded, color: AppColors.primary),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Master Device', style: AppTextStyles.headlineSmall),
              Text('Capture audio & broadcast', style: AppTextStyles.bodySmall),
              Icon(Icons.arrow_forward_ios_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class SlaveDevices extends StatefulWidget {
  const SlaveDevices({super.key});

  @override
  State<SlaveDevices> createState() => _SlaveDevices();
}

class _SlaveDevices extends State<SlaveDevices> {
  int devicesConnected = 0;

  // _SlaveDevice() {
  //   devicesConnected = 0;
  // }

  int connection() {
    return devicesConnected++;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: const GradientBoxBorder(
          gradient: AppColors.cardGradient,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.cell_tower_rounded, color: AppColors.secondary),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Slave Devices', style: AppTextStyles.headlineSmall),
              Text('Connect & Listen', style: AppTextStyles.bodySmall),
              Icon(Icons.arrow_forward_ios_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class FootNote extends StatelessWidget {
  const FootNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [Text('v1.0.0', style: AppTextStyles.labelSmall)]);
  }
}
