/// Speakify utility functions & constants.
library;

/// App-wide constants.
class AppConstants {
  AppConstants._();

  /// App display name.
  static const String appName = 'Speakify';

  // App Description
  static const String appDes = 'Multi-device audio';

  /// Maximum number of Slave devices that can connect to a Master.
  static const int maxSlaveDevices = 10;

  /// Default UDP multicast port for audio streaming.
  static const int defaultStreamPort = 5353;

  /// Default TCP port for control channel communication.
  static const int defaultControlPort = 5354;

  /// Target audio latency in milliseconds.
  static const int targetLatencyMs = 20;

  /// Audio sample rate in Hz.
  static const int sampleRate = 48000;

  /// Audio channels (1 = mono, 2 = stereo).
  static const int audioChannels = 2;
}
