import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';

/// Decodes incoming Opus-compressed audio frames back to raw 16-bit PCM.
///
/// Each call to [decode] takes a single Opus frame (as received from the UDP
/// packet payload) and returns the decompressed [Uint8List] PCM bytes that
/// [AudioPlaybackService] can feed directly to the speaker.
class OpusDecoderService {
  late final SimpleOpusDecoder _decoder;
  bool _isInitialized = false;

  /// Initialize the Opus decoder. Must be called once after [opus_flutter.load()].
  void initialize() {
    _decoder = SimpleOpusDecoder(sampleRate: 44100, channels: 1);
    _isInitialized = true;
    debugPrint('OpusDecoderService: Initialized');
  }

  /// Decode a single Opus-encoded [frame] back to raw 16-bit PCM bytes.
  /// Returns `null` on error so the caller can skip the frame gracefully.
  Uint8List? decode(Uint8List frame) {
    if (!_isInitialized) return null;
    try {
      final int16Samples = _decoder.decode(input: frame);
      return int16Samples.buffer.asUint8List();
    } catch (e) {
      debugPrint('OpusDecoderService: Decode error: $e');
      return null;
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
