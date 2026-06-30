import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';

// Opus frame sizes supported by the encoder (in samples at 44100Hz).
// We use 960 samples = ~21.8ms per frame — the best latency/quality tradeoff.
const int opusFrameSamples = 960;

// Bytes per frame: 960 samples × 2 bytes (16-bit PCM) × 1 channel = 1920 bytes.
const int opusFrameBytes = opusFrameSamples * 2;

// Encodes raw 16-bit mono PCM chunks into Opus compressed frames.

// Incoming PCM from [AudioCaptureService] may not be aligned to the Opus
// frame boundary (960 samples = 1920 bytes). This service accumulates bytes
// in an internal buffer and emits exactly one Opus-encoded frame whenever
// it has collected enough samples.
class OpusEncoderService {
  late final SimpleOpusEncoder _encoder;
  bool _isInitialized = false;

  // Accumulation buffer — holds incomplete PCM frames waiting to be encoded.
  final _buffer = <int>[];

  /// Initialize the Opus encoder. Must be called once after [opus_flutter.load()].
  void initialize() {
    _encoder = SimpleOpusEncoder(
      sampleRate: 44100,
      channels: 1,
      application: Application.audio,
    );
    _isInitialized = true;
    debugPrint('OpusEncoderService: Initialized (frame=${opusFrameSamples}s / ${opusFrameBytes}B)');
  }

  // Feed a raw PCM [Uint8List] chunk. Returns a list of encoded Opus frames
  // (one [Uint8List] per 960-sample frame). May return an empty list if
  // there are not yet enough bytes for a full frame.
  List<Uint8List> encode(Uint8List pcmChunk) {
    if (!_isInitialized) return [];

    _buffer.addAll(pcmChunk);

    final encodedFrames = <Uint8List>[];

    // Drain whole frames from the buffer.
    while (_buffer.length >= opusFrameBytes) {
      final frameBytes = Uint8List.fromList(_buffer.sublist(0, opusFrameBytes));
      _buffer.removeRange(0, opusFrameBytes);

      final int16Samples = frameBytes.buffer.asInt16List();
      try {
        final encoded = _encoder.encode(input: int16Samples);
        encodedFrames.add(Uint8List.fromList(encoded));
      } catch (e) {
        debugPrint('OpusEncoderService: Encode error: $e');
      }
    }

    return encodedFrames;
  }

  // Discard any partially accumulated buffer (call on stop).
  void reset() => _buffer.clear();

  void dispose() {
    reset();
    _isInitialized = false;
  }
}
