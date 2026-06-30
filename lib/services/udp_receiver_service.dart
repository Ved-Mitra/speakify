import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speakify/services/opus_decoder_service.dart';

/// Codec flag values — must match [UdpStreamerService].
const int _codecRawPcm = 0x00;
const int _codecOpus = 0x01;

/// A decoded audio packet ready for the jitter buffer.
class AudioPacket {
  final int sequenceNumber; // bytes 0-3
  final int timestampUs;    // bytes 4-11 (microseconds, from Master clock)
  final Uint8List pcm;      // decoded 16-bit PCM bytes
  const AudioPacket(this.sequenceNumber, this.timestampUs, this.pcm);
}

/// Listens on the UDP audio port and emits [AudioPacket] objects.
///
/// Packet format (15+ bytes):
///  bytes  0-3  → sequence number (uint32, big-endian)
///  bytes  4-11 → capture timestamp in microseconds (uint64, big-endian)
///  bytes 12-13 → payload length (uint16, big-endian)
///  byte   14   → codec flag: 0x00 = raw PCM, 0x01 = Opus
///  bytes 15+   → payload
class UdpReceiverService {
  RawDatagramSocket? _socket;

  final StreamController<AudioPacket> _pcmStreamController =
      StreamController<AudioPacket>.broadcast();

  Stream<AudioPacket> get pcmStream => _pcmStreamController.stream;

  static const int audioPort = 5355;
  int _lastSequence = -1;

  // ── Opus decoder ──────────────────────────────────────────────
  final _opusDecoder = OpusDecoderService();

  // ── Packet validation ─────────────────────────────────────────
  bool _verifyPacket(Uint8List data) {
    if (data.length < 15) {
      // 15 = new header size
      debugPrint('UdpReceiverService: Packet too small (${data.length}B)');
      return false;
    }

    final buffer = ByteData.sublistView(data);
    final currentSeq = buffer.getUint32(0, Endian.big);

    if (_lastSequence != -1 && currentSeq != _lastSequence + 1) {
      debugPrint(
        'UdpReceiverService: Missing packet(s): expected ${_lastSequence + 1}, got $currentSeq',
      );
    }

    final payloadLength = buffer.getUint16(12, Endian.big);
    if (data.length != payloadLength + 15) {
      debugPrint('UdpReceiverService: Payload size mismatch — dropping packet');
      return false;
    }

    return true;
  }

  // ── Packet processing ─────────────────────────────────────────
  void _handlePacket(Uint8List data) {
    if (!_verifyPacket(data)) return;

    final buffer = ByteData.sublistView(data);
    _lastSequence = buffer.getUint32(0, Endian.big);
    final timestamp = buffer.getUint64(4, Endian.big);
    final codecFlag = buffer.getUint8(14);
    final payload = data.sublist(15);

    Uint8List? pcm;

    if (codecFlag == _codecOpus) {
      pcm = _opusDecoder.decode(payload);
      if (pcm == null) {
        debugPrint('UdpReceiverService: Opus decode failed — dropping packet');
        return;
      }
    } else if (codecFlag == _codecRawPcm) {
      pcm = payload;
    } else {
      debugPrint('UdpReceiverService: Unknown codec flag 0x${codecFlag.toRadixString(16)} — dropping');
      return;
    }

    _pcmStreamController.add(AudioPacket(_lastSequence, timestamp, pcm));
  }

  // ── Lifecycle ─────────────────────────────────────────────────
  Future<void> start() async {
    _opusDecoder.initialize();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, audioPort);
    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) _handlePacket(datagram.data);
      }
    });
    debugPrint('UdpReceiverService: Listening on port $audioPort');
  }

  void stop() {
    _socket?.close();
    _socket = null;
    if (!_pcmStreamController.isClosed) {
      _pcmStreamController.close();
    }
  }

  void dispose() {
    stop();
    _opusDecoder.dispose();
  }
}
