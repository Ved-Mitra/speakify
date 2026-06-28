import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class UdpReceiverService {
  RawDatagramSocket? _socket;
  final StreamController<Uint8List> _pcmStreamController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get pcmStream => _pcmStreamController.stream;
  static const int audioPort = 5355; // TCP control
  int _lastSequence = -1;

  bool _verifyPacket(Uint8List data) {
    if (data.length < 14) {
      debugPrint("Packet too small");
      return false;
    }
    
    final buffer = ByteData.sublistView(data);
    final currentSeq = buffer.getUint32(0, Endian.big);
    
    if (_lastSequence != -1 && currentSeq != _lastSequence + 1) {
      debugPrint("Missing Packet(s): expected ${_lastSequence + 1}, got $currentSeq");
    }
    
    final payloadLength = buffer.getUint16(12, Endian.big);
    if (data.length != payloadLength + 14) {
      debugPrint("Payload loss or malformed packet");
      return false;
    }
    return true;
  }

  void _handlePacket(Uint8List data) {
    if (!_verifyPacket(data)) {
      return;
    }
    _lastSequence = ByteData.sublistView(data).getUint32(0, Endian.big);
    Uint8List payload = data.sublist(14);
    _pcmStreamController.add(payload);
  }

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, audioPort);

    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _handlePacket(datagram.data);
        }
      }
    });
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
  }
}
