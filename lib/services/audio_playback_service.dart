import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

// service for playback in slave devices
class AudioPlaybackService {
  bool _isSetup = false;
  StreamSubscription<Uint8List>? _streamSubscription;

  Future<void> startPlayback(Stream<Uint8List> pcmStream) async {
    try {
      await FlutterPcmSound.setup(sampleRate: 44100, channelCount: 1);
      await FlutterPcmSound.setFeedThreshold(8000);
      _isSetup = true;

      debugPrint("AudioPlaybackService: Setup complete");

      _streamSubscription = pcmStream.listen((Uint8List chunk) async {
        if (!_isSetup) {
          return;
        }
        final samples = chunk.buffer.asInt16List();
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
      });
      FlutterPcmSound.start();
      debugPrint("AudioPlaybackService: PLayback started");
    } catch (error) {
      debugPrint("AudioPLaybackService Error: $error");
    }
  }

  Future<void> stopPlayback() async {
    if (!_isSetup) {
      return;
    }
    _isSetup = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    debugPrint("AudioPlaybackService: Stopped");
  }

  void dispose() {
    stopPlayback();
    FlutterPcmSound.release();
  }
}
