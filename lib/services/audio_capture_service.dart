import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Audio input source for the Master device.
enum AudioInputSource {
  aux,           // AUX / 3.5mm line-in from TV
  bluetoothA2dp, // Bluetooth A2DP Sink (coming soon)
}

/// Service that captures audio from AUX/line-in input on the Master device.
///
/// When a 3.5mm cable is plugged into the phone, Android automatically
/// routes audio input from the cable instead of the built-in mic.
/// We capture that audio as raw PCM data and expose it as a stream
/// for the next stage (encoding + network transmission).
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();

  // ── Audio config ────────────────────────────────────────────
  static const int sampleRate = 44100;
  static const int numChannels = 1; // Mono — half bandwidth of stereo
  static const int bitsPerSample = 16;

  // _config is now built dynamically in startCapture to pass the device

  // ── State ───────────────────────────────────────────────────
  bool _isCapturing = false;
  AudioInputSource _currentSource = AudioInputSource.aux;
  StreamSubscription<List<int>>? _recordSubscription;

  /// Whether audio is currently being captured.
  bool get isCapturing => _isCapturing;

  /// Currently selected audio input source.
  AudioInputSource get currentSource => _currentSource;

  // ── Audio output stream ─────────────────────────────────────
  // This stream will be consumed by the encoder/streamer in Phase 3.
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  /// Raw PCM audio data stream. Each emission is a chunk of
  /// PCM 16-bit, 44100 Hz, mono audio bytes.
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  // ── Audio level metering ────────────────────────────────────
  // Drives the visual level meter in the UI.
  final ValueNotifier<double> audioLevel = ValueNotifier(0.0);

  // ── Source selection ────────────────────────────────────────

  /// Set the audio input source. Can only be changed while NOT capturing.
  void setSource(AudioInputSource source) {
    if (_isCapturing) {
      debugPrint('AudioCaptureService: Cannot change source while capturing');
      return;
    }
    _currentSource = source;
  }

  // ── Start / Stop ────────────────────────────────────────────

  /// Start capturing audio from the selected input source.
  /// Returns `true` if capture started successfully.
  Future<bool> startCapture() async {
    if (_isCapturing) {
      debugPrint('AudioCaptureService: Already capturing');
      return true;
    }

    if (_currentSource == AudioInputSource.bluetoothA2dp) {
      debugPrint('AudioCaptureService: BT A2DP Sink not implemented yet');
      return false;
    }

    // Check if we have permission to record audio.
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('AudioCaptureService: No audio recording permission');
      return false;
    }

    try {
      // 1. List all available input devices
      final devices = await _recorder.listInputDevices();
      InputDevice? wiredDevice;
      
      debugPrint('--- Available Audio Input Devices ---');
      for (final d in devices) {
        debugPrint(' - ${d.label} (ID: ${d.id})');
        
        // 2. Look for a wired headset or AUX input
        final labelLower = d.label.toLowerCase();
        if (labelLower.contains('wired') || 
            labelLower.contains('headset') || 
            labelLower.contains('aux') ||
            labelLower.contains('usb')) {
          wiredDevice = d;
        }
      }

      if (wiredDevice != null) {
        debugPrint('AudioCaptureService: Forcing input to wired device: ${wiredDevice.label}');
      } else {
        debugPrint('AudioCaptureService: No wired device detected, falling back to default mic.');
      }

      // Start streaming raw PCM audio from the selected input source.
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
          device: wiredDevice, // Force the specific device here!
        ),
      );

      _recordSubscription = stream.listen(
        (List<int> data) {
          final bytes = Uint8List.fromList(data);

          // Forward raw PCM data to consumers (encoder/streamer).
          if (!_audioStreamController.isClosed) {
            _audioStreamController.add(bytes);
          }

          // Calculate audio level for the UI meter.
          _updateAudioLevel(bytes);
        },
        onError: (error) {
          debugPrint('AudioCaptureService: Stream error: $error');
        },
        onDone: () {
          debugPrint('AudioCaptureService: Stream ended');
          _isCapturing = false;
          audioLevel.value = 0.0;
        },
      );

      _isCapturing = true;
      debugPrint('AudioCaptureService: Capture started (${sampleRate}Hz, '
          '${numChannels}ch, ${bitsPerSample}bit)');
      return true;
    } catch (e) {
      debugPrint('AudioCaptureService: Failed to start capture: $e');
      return false;
    }
  }

  /// Stop capturing audio.
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('AudioCaptureService: Error stopping recorder: $e');
    }

    _recordSubscription?.cancel();
    _recordSubscription = null;
    _isCapturing = false;
    audioLevel.value = 0.0;

    debugPrint('AudioCaptureService: Capture stopped');
  }

  // ── Audio level calculation ─────────────────────────────────

  /// Calculate RMS (root mean square) amplitude from PCM 16-bit data.
  /// Updates the [audioLevel] ValueNotifier (0.0 to 1.0).
  void _updateAudioLevel(Uint8List data) {
    if (data.length < 2) return;

    double sumSquares = 0;
    final sampleCount = data.length ~/ 2; // 2 bytes per sample (16-bit)

    for (int i = 0; i < data.length - 1; i += 2) {
      // Convert 2 bytes to signed int16 (little-endian).
      int sample = data[i] | (data[i + 1] << 8);
      if (sample > 32767) sample -= 65536; // Handle sign bit
      sumSquares += sample * sample;
    }

    final rms = sqrt(sumSquares / sampleCount);
    final level = (rms / 32768.0).clamp(0.0, 1.0); // Normalize to 0.0–1.0
    audioLevel.value = level;
  }

  // ── Cleanup ─────────────────────────────────────────────────

  /// Dispose all resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    await stopCapture();
    _recorder.dispose();
    audioLevel.dispose();
    if (!_audioStreamController.isClosed) {
      _audioStreamController.close();
    }
  }
}
