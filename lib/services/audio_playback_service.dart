import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps a raw PCM stream in a fake WAV header so [AudioPlayer] can play it.
///
/// Since just_audio expects a file-like source with a header that describes
/// the audio format, we inject a 44-byte WAV header at the front of our
/// endless UDP PCM stream. The player reads the header once, understands the
/// format (44100Hz, Mono, 16-bit PCM), and then plays everything that follows.
class _PcmStreamAudioSource extends StreamAudioSource {
  final Stream<Uint8List> pcmStream;
  final int sampleRate;
  final int numChannels;

  _PcmStreamAudioSource({
    required this.pcmStream,
    this.sampleRate = 44100,
    this.numChannels = 1,
  });

  /// Build a standard 44-byte WAV header for a PCM stream.
  Uint8List _buildWavHeader() {
    // We use a "fake" massive data length so the player never thinks the
    // stream is finished. The actual audio ends when the socket closes.
    const int dataLength = 0x7FFFFFFF;
    final byteRate = sampleRate * numChannels * 2; // 16-bit = 2 bytes/sample

    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataLength, Endian.little); // chunk size
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt sub-chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); //  (space)
    header.setUint32(16, 16, Endian.little);           // subchunk1 size
    header.setUint16(20, 1, Endian.little);            // PCM format
    header.setUint16(22, numChannels, Endian.little);  // channels
    header.setUint32(24, sampleRate, Endian.little);   // sample rate
    header.setUint32(28, byteRate, Endian.little);     // byte rate
    header.setUint16(32, numChannels * 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little);           // bits per sample
    // data sub-chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);   // data length

    return header.buffer.asUint8List();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final wavHeader = _buildWavHeader();

    Stream<List<int>> generateStream() async* {
      yield wavHeader;
      await for (final chunk in pcmStream) {
        yield chunk;
      }
    }

    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: start ?? 0,
      stream: generateStream(),
      contentType: 'audio/wav',
    );
  }
}

/// Service that plays a raw PCM stream on the Slave device's speaker.
///
/// Used in Slave mode to consume the [UdpReceiverService.pcmStream] and
/// render it as real-time audio output.
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> startPlayback(Stream<Uint8List> pcmStream) async {
    try {
      final source = _PcmStreamAudioSource(pcmStream: pcmStream);
      await _player.setAudioSource(source);
      await _player.play();
      debugPrint('AudioPlaybackService: Playback started');
    } catch (e) {
      debugPrint('AudioPlaybackService: Error starting playback: $e');
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    debugPrint('AudioPlaybackService: Playback stopped');
  }

  void dispose() {
    _player.dispose();
  }
}
