import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:speakify/services/opus_encoder_service.dart';

/// Codec flag values stored in packet header byte 14.
const int codecRawPcm = 0x00;
const int codecOpus = 0x01;

/// Streams audio to all registered Slave IPs over UDP.

// Packet format (15+ bytes):
//  bytes  0-3  → sequence number (uint32, big-endian)
//  bytes  4-11 → capture timestamp in microseconds (uint64, big-endian)
//  bytes 12-13 → payload length (uint16, big-endian)
//  byte   14   → codec flag: 0x00 = raw PCM, 0x01 = Opus
/// bytes 15+   → payload (raw PCM or Opus frame)
class UdpStreamerService {
  RawDatagramSocket? _socket;
  final List<String> _slaveIps = [];
  int _sequenceNumber = 0;
  static const int audioPort = 5355;

  // ── Opus encoder ──────────────────────────────────────────────
  final _opusEncoder = OpusEncoderService();

  /// Whether to compress audio with Opus before sending.
  /// Set to false to send raw PCM (useful for debugging).
  bool useOpus = true;

  Uint8List _buildPacket(Uint8List payload, {required int codecFlag}) {
    const headerSize = 15; // +1 byte for codec flag vs old 14-byte header
    final packet = ByteData(headerSize + payload.length);
    packet.setUint32(0, _sequenceNumber, Endian.big);
    packet.setUint64(4, DateTime.now().microsecondsSinceEpoch, Endian.big);
    packet.setUint16(12, payload.length, Endian.big);
    packet.setUint8(14, codecFlag);

    final packetBytes = packet.buffer.asUint8List();
    packetBytes.setRange(headerSize, headerSize + payload.length, payload);
    return packetBytes;
  }

  Future<void> start() async {
    _opusEncoder.initialize();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.broadcastEnabled = true;
    debugPrint('UdpStreamerService: started (opus=${useOpus})');
  }

  void addSlave(String ip) {
    if (!_slaveIps.contains(ip)) {
      _slaveIps.add(ip);
      debugPrint('Master: Added slave IP $ip to UDP streamer');
    }
  }

  void send(Uint8List pcmChunk) {
    if (_socket == null) return;

    if (useOpus) {
      // Encoder accumulates bytes and emits complete 960-sample frames.
      final frames = _opusEncoder.encode(pcmChunk);
      for (final frame in frames) {
        final packet = _buildPacket(frame, codecFlag: codecOpus);
        _sendToAll(packet);
        _sequenceNumber++;
      }
    } else {
      // Raw PCM path (debugging).
      final packet = _buildPacket(pcmChunk, codecFlag: codecRawPcm);
      _sendToAll(packet);
      _sequenceNumber++;
    }
  }

  void _sendToAll(Uint8List packet) {
    for (final ip in _slaveIps) {
      _socket!.send(packet, InternetAddress(ip), audioPort);
    }
  }

  void stop() {
    _opusEncoder.reset();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _slaveIps.clear();
    _sequenceNumber = 0;
    _opusEncoder.dispose();
  }
}
