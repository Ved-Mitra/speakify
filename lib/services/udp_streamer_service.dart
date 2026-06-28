import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class UdpStreamerService {
  RawDatagramSocket? _socket;
  final List<String> _slaveIps = [];
  int _sequenceNumber = 0;
  static const int audioPort = 5355; // TCP control

  Uint8List _buildPacket(Uint8List payload) {
    final headerSize = 14;
    /*
      bytes 0-3 --> sequence number
      bytes 4-11 --> timestamp
      bytes 12-13 --> payload length
      bytes 14+ --> payload
    */
    final packet = ByteData(headerSize + payload.length);
    packet.setUint32(0, _sequenceNumber, Endian.big);
    packet.setUint64(4, DateTime.now().microsecondsSinceEpoch, Endian.big);
    packet.setUint16(12, payload.length, Endian.big);

    final packetBytes = packet.buffer.asUint8List();
    packetBytes.setRange(headerSize, headerSize + payload.length, payload);
    return packetBytes;
  }

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.broadcastEnabled = true;
  }

  void addSlave(String ip) {
    if (!_slaveIps.contains(ip)) {
      _slaveIps.add(ip);
      debugPrint('Master: Added slave IP $ip to UDP streamer');
    }
  }

  void send(Uint8List pcmChunk) {
    if (_socket == null) {
      debugPrint("Socket is NULL in UDP Streamer service");
      return;
    }
    final packet = _buildPacket(pcmChunk);
    for (String ip in _slaveIps) {
      _socket!.send(packet, InternetAddress(ip), audioPort);
    }
    _sequenceNumber++;
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _slaveIps.clear();
    _sequenceNumber = 0;
  }
}
