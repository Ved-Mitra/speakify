import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:speakify/services/udp_receiver_service.dart';

class JitterBufferService {
  int bufferMs = 0;
  final StreamController<Uint8List> _pcmStreamerController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get pcmStream => _pcmStreamerController.stream;
  StreamSubscription<AudioPacket>? _pcmSourceStream;
  final packets = PriorityQueue<AudioPacket>((a,b)=> a.sequenceNumber.compareTo(b.sequenceNumber));
  Timer? _packetTimer;
  JitterBufferService(this.bufferMs);

  Future<void> start (Stream<AudioPacket> pcmAudioSourceStream) async{
    try {
      _pcmSourceStream = pcmAudioSourceStream.listen((AudioPacket packet) async {
          packets.add(packet);
      });

      debugPrint("JitterService started with no error");
      // packet timer to sen packets to slave devices at reguler time intervals
      _packetTimer = Timer.periodic(const Duration(milliseconds: 10), (_) => _sendPacketToAll());
    } catch(error) {
      debugPrint("JitterService Error $error");
    }
  }

  void _sendPacketToAll() {
    if(packets.isEmpty){
      return;
    }
    int arrivalTime = packets.first.timestampUs;
    int nowTime = DateTime.now().microsecondsSinceEpoch;

    // bufferMs*1000 to make units equal
    while (nowTime - arrivalTime > bufferMs*1000 ) {
      _pcmStreamerController.add(packets.removeFirst().pcm);
      if(packets.isNotEmpty){
        arrivalTime=packets.first.timestampUs;
        nowTime = DateTime.now().microsecondsSinceEpoch;
      }
      else {
        break;
      }
    }
  }

  void stop() {
    _pcmSourceStream!.cancel();
    if(!_pcmStreamerController.isClosed){
      _pcmStreamerController.close();
    }
  }

  void dispose(){
    stop();
    packets.clear();
    _packetTimer!.cancel();
  }
}
