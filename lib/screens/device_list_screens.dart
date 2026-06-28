import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speakify/models/device_role.dart';
import 'package:speakify/models/slave_connection_type.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/models/peer_device.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:speakify/utils/constants.dart';
import 'package:speakify/services/bluetooth_scan_service.dart';
import 'package:speakify/services/wifi_connection_service.dart';
import 'package:speakify/services/audio_capture_service.dart';
import 'package:speakify/services/udp_receiver_service.dart';
import 'package:speakify/services/udp_streamer_service.dart';
import 'package:speakify/services/audio_playback_service.dart';
import 'package:speakify/services/jitter_buffer_service.dart';

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

  // ── Audio capture (Master only) ────────────────────────────
  AudioCaptureService? _audioService;
  bool _isCapturing = false;
  StreamSubscription<Uint8List>? _captureSubscription; // PCM → UDP pipeline

  // Audio -- send : Master
  UdpStreamerService? _udpStreamer;

  // Audio -- receive + playback : Slave
  UdpReceiverService? _udpReceiver;
  AudioPlaybackService? _audioPlayback;
  AudioPlaybackService? _masterPlayback;

  //Jitter for slave mode only
  JitterBufferService? _jitterBuffer;

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

      // Master mode: dynamically add newly connected slaves to the UDP streamer
      if (widget.role == DeviceRole.master && _udpStreamer != null) {
        for (final device in devices) {
          if (device.ipAddress != null) {
            _udpStreamer!.addSlave(device.ipAddress!);
          }
        }
      }
    });

    // ── Audio capture + UDP streamer (Master only) ────────────
    if (widget.role == DeviceRole.master) {
      _audioService = AudioCaptureService();
      _udpStreamer = UdpStreamerService();
      _masterPlayback = AudioPlaybackService();
    }

    // ── UDP receiver + Playback (Slave only) ──────────────────
    if (widget.role == DeviceRole.slave) {
      _udpReceiver = UdpReceiverService();
      _audioPlayback = AudioPlaybackService();
      _jitterBuffer = JitterBufferService(60);

      // React when the Master disconnects (socket closed / error)
      _wifiService.masterConnectionNotifier.addListener(
        _onMasterConnectionChanged,
      );
    }

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
        _ipController.clear();
        _startAudioReceiving();
      }
    }
  }

  // Slave mode: start receiving UDP audio packets and play them.
  Future<void> _startAudioReceiving() async {
    if (_udpReceiver == null || _audioPlayback == null) return;

    await _udpReceiver!.start();
    debugPrint(
      'Slave: UDP receiver started on port ${UdpReceiverService.audioPort}',
    );

    // Diagnostic: log every 100th packet so we know data is flowing
    int _packetCount = 0;
    _udpReceiver!.pcmStream.listen((AudioPacket pcmData) {
      _packetCount++;
      if (_packetCount % 100 == 0) {
        debugPrint(
          'Slave: $_packetCount packets received (${pcmData.pcm.length} bytes each)',
        );
      }
    });

    // Start playing the incoming PCM stream through the speaker.
    debugPrint('Slave: Starting audio playback...');
    await _jitterBuffer!.start(_udpReceiver!.pcmStream);
    await _audioPlayback!.startPlayback(_jitterBuffer!.pcmStream);
    debugPrint('Slave: Playback started');
  }

  // Master mode: start the UDP streamer and pipe audio into it + Audio Playback
  Future<void> _startAudioStreaming() async {
    if (_udpStreamer == null) return;

    // Start the UDP socket.
    await _udpStreamer!.start();
    await _masterPlayback?.startPlayback(_audioService!.audioStream);

    // Add all currently connected slave IPs to the streamer.
    for (final device in _wifiDevices) {
      if (device.ipAddress != null) {
        _udpStreamer!.addSlave(device.ipAddress!);
      }
    }

    // Pipe every PCM chunk from AudioCaptureService → UdpStreamerService.
    _captureSubscription = _audioService!.audioStream.listen((
      Uint8List pcmChunk,
    ) {
      _udpStreamer!.send(pcmChunk);
    });
  }

  // Master mode: stop the UDP streamer and cancel the pipeline.
  Future<void> _stopAudioStreaming() async {
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    _udpStreamer?.stop();
    _masterPlayback?.stopPlayback();
  }

  /// Master mode: toggle audio capture + streaming.
  Future<void> _toggleCapture() async {
    if (_audioService == null) return;

    if (_isCapturing) {
      await _stopAudioStreaming();
      await _audioService!.stopCapture();
    } else {
      final started = await _audioService!.startCapture();
      if (started) await _startAudioStreaming();
    }
    if (mounted) {
      setState(() => _isCapturing = _audioService!.isCapturing);
    }
  }

  /// Master mode: change audio input source.
  void _setAudioSource(AudioInputSource source) {
    _audioService?.setSource(source);
    if (mounted) setState(() {});
  }

  // Slave mode: react when master connection state changes
  void _onMasterConnectionChanged() {
    if (!mounted) return;
    final connected = _wifiService.masterConnectionNotifier.value;
    setState(() {}); // rebuild the UI badge
    if (!connected) {
      // Stop receiving and playback when master disappears
      _audioPlayback?.stopPlayback();
      _udpReceiver?.stop();
    }
  }

  @override
  void dispose() {
    _btSubscription?.cancel();
    _btService.dispose();
    _wifiSubscription?.cancel();
    _wifiService.masterConnectionNotifier.removeListener(
      _onMasterConnectionChanged,
    );
    _wifiService.dispose();
    _captureSubscription?.cancel();
    _audioService?.dispose();
    _udpStreamer?.dispose();
    _masterPlayback?.dispose();
    _audioPlayback?.dispose();
    _udpReceiver?.dispose();
    _ipController.dispose();
    _jitterBuffer?.dispose();
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
              // Audio capture props (Master only)
              audioService: _audioService,
              isCapturing: _isCapturing,
              onToggleCapture: isMaster ? _toggleCapture : null,
              onSetAudioSource: isMaster ? _setAudioSource : null,
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
/// In Master mode, also shows the Audio Source card.
class _DeviceListBody extends StatelessWidget {
  final List<PeerDevice> devices;
  final bool isMaster;
  final String? masterIp;
  final TextEditingController? slaveIpController;
  final bool isConnecting;
  final bool isConnectedToMaster;
  final VoidCallback? onConnect;

  // Audio capture props (Master only)
  final AudioCaptureService? audioService;
  final bool isCapturing;
  final VoidCallback? onToggleCapture;
  final void Function(AudioInputSource)? onSetAudioSource;

  const _DeviceListBody({
    required this.devices,
    required this.isMaster,
    this.masterIp,
    this.slaveIpController,
    this.isConnecting = false,
    this.isConnectedToMaster = false,
    this.onConnect,
    this.audioService,
    this.isCapturing = false,
    this.onToggleCapture,
    this.onSetAudioSource,
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
        if (isMaster && masterIp != null) _MasterIpBanner(ip: masterIp!),

        // ── Slave: Show IP input + Connect button ──────────────
        if (!isMaster)
          _SlaveConnectCard(
            controller: slaveIpController!,
            isConnecting: isConnecting,
            isConnected: isConnectedToMaster,
            onConnect: onConnect!,
          ),

        // ── Master: Audio Source card ──────────────────────────
        if (isMaster && audioService != null)
          _AudioSourceCard(
            audioService: audioService!,
            isCapturing: isCapturing,
            onToggleCapture: onToggleCapture!,
            onSetSource: onSetAudioSource!,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
          ...wifiDevices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceTile(device: device),
            ),
          ),

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
          ...btDevices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeviceTile(device: device),
            ),
          ),

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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_tethering_rounded,
            color: AppColors.primary,
            size: 28,
          ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
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
          Text(title, style: AppTextStyles.titleMedium.copyWith(color: color)),
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
    final Color accentColor = device.isConnected
        ? AppColors.success
        : AppColors.textDisabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint(
            'Tapped device: ${device.name} (${device.connectionType.name})',
          );
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
                      color:
                          (device.isBluetooth
                                  ? AppColors.secondary
                                  : AppColors.primary)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      device.isBluetooth ? 'BT' : 'Wi-Fi',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: device.isBluetooth
                            ? AppColors.secondary
                            : AppColors.primary,
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

/// Audio source selector + capture controls for Master mode.
/// Shows source radio buttons, start/stop button, and live level meter.
class _AudioSourceCard extends StatelessWidget {
  final AudioCaptureService audioService;
  final bool isCapturing;
  final VoidCallback onToggleCapture;
  final void Function(AudioInputSource) onSetSource;

  const _AudioSourceCard({
    required this.audioService,
    required this.isCapturing,
    required this.onToggleCapture,
    required this.onSetSource,
  });

  @override
  Widget build(BuildContext context) {
    final currentSource = audioService.currentSource;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCapturing
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.accent.withValues(alpha: 0.3),
        ),
        boxShadow: isCapturing
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.1),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Icon(
                isCapturing
                    ? Icons.graphic_eq_rounded
                    : Icons.music_note_rounded,
                color: isCapturing ? AppColors.success : AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Audio Source',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isCapturing ? AppColors.success : AppColors.accent,
                ),
              ),
              const Spacer(),
              if (isCapturing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Source selection ─────────────────────────────────
          // AUX option
          _SourceOption(
            icon: Icons.cable_rounded,
            label: 'AUX (3.5mm cable)',
            subtitle: 'Line-in from TV / Console',
            isSelected: currentSource == AudioInputSource.aux,
            isEnabled: !isCapturing,
            onTap: () => onSetSource(AudioInputSource.aux),
          ),
          const SizedBox(height: 6),
          // BT A2DP option (coming soon)
          _SourceOption(
            icon: Icons.bluetooth_audio_rounded,
            label: 'Bluetooth A2DP',
            subtitle: 'Coming soon',
            isSelected: currentSource == AudioInputSource.bluetoothA2dp,
            isEnabled: false, // Not implemented yet
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // ── Capture button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onToggleCapture,
              icon: Icon(
                isCapturing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 22,
              ),
              label: Text(
                isCapturing ? 'Stop Capture' : 'Start Capture',
                style: AppTextStyles.titleMedium.copyWith(
                  color: isCapturing ? AppColors.error : AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCapturing
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.accent,
                foregroundColor: isCapturing
                    ? AppColors.error
                    : AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: isCapturing
                    ? BorderSide(color: AppColors.error.withValues(alpha: 0.5))
                    : BorderSide.none,
              ),
            ),
          ),

          // ── Audio level meter (only visible while capturing) ──
          if (isCapturing) ...[
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: audioService.audioLevel,
              builder: (context, level, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Audio Level', style: AppTextStyles.labelSmall),
                        Text(
                          '${(level * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _levelColor(level),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Level bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: level,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _levelColor(level),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          // ── Config info ─────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${AudioCaptureService.sampleRate} Hz • '
              '${AudioCaptureService.numChannels == 1 ? "Mono" : "Stereo"} • '
              'PCM ${AudioCaptureService.bitsPerSample}-bit',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Return green/yellow/red based on audio level.
  Color _levelColor(double level) {
    if (level < 0.4) return AppColors.success;
    if (level < 0.75) return AppColors.warning;
    return AppColors.error;
  }
}

/// A single radio-style source option row.
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !isEnabled
        ? AppColors.textDisabled
        : isSelected
        ? AppColors.accent
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: color,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
