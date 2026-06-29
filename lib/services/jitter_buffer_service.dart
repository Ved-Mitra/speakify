import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:speakify/services/udp_receiver_service.dart';

/// Holds incoming [AudioPacket]s in a priority queue and releases them to
/// [pcmStream] at the correct time using the Master's presentation timestamp.
///
/// How it works:
///   1. Every packet carries a Master-clock timestamp (µs) from the moment
///      it was captured.
///   2. [clockOffsetUs] tells us how far the Master clock is ahead of ours.
///   3. A packet becomes due when:
///        localNow  >=  masterTimestamp - clockOffset + bufferMs*1000
///      i.e. we hold each packet for [bufferMs] milliseconds beyond its
///      "local equivalent" capture time, smoothing out network jitter.
///   4. If a packet is inexplicably late (>500ms overdue), it is dropped to
///      prevent stale audio from backing up the queue.
class JitterBufferService {
  /// How long (ms) to hold a packet beyond its scheduled play time.
  /// Increase this if you hear pops/gaps on congested Wi-Fi.
  int bufferMs;

  /// Clock offset (µs) between Master and Slave clocks.
  /// Supplied by [WifiConnectionService.clockOffsetUs] and updated every 2s.
  int clockOffsetUs = 0;

  final _pcmController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get pcmStream => _pcmController.stream;

  StreamSubscription<AudioPacket>? _sourceSub;
  final _queue = PriorityQueue<AudioPacket>(
    (a, b) => a.sequenceNumber.compareTo(b.sequenceNumber),
  );
  Timer? _ticker;

  JitterBufferService(this.bufferMs);

  Future<void> start(Stream<AudioPacket> source) async {
    try {
      _sourceSub = source.listen(_queue.add);
      _ticker = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => _drain(),
      );
      debugPrint('JitterBufferService: started (buffer=${bufferMs}ms)');
    } catch (e) {
      debugPrint('JitterBufferService: start error $e');
    }
  }

  void _drain() {
    if (_queue.isEmpty) return;

    final int localNow = DateTime.now().microsecondsSinceEpoch;
    final int dropThresholdUs = bufferMs * 1000 + 500000; // 500ms stale limit

    while (_queue.isNotEmpty) {
      final packet = _queue.first;

      // Convert Master timestamp to an equivalent Slave-local timestamp.
      final int localPacketTime = packet.timestampUs - clockOffsetUs;

      // The packet is due when local clock has passed its scheduled play time.
      final int playAtUs = localPacketTime + bufferMs * 1000;

      if (localNow >= playAtUs) {
        _queue.removeFirst();

        // Drop packets that are more than 500ms overdue — they're too stale.
        if (localNow - playAtUs > dropThresholdUs) {
          debugPrint('JitterBufferService: Dropped stale packet seq=${packet.sequenceNumber}');
          continue;
        }

        if (!_pcmController.isClosed) {
          _pcmController.add(packet.pcm);
        }
      } else {
        break; // Next packet isn't due yet — wait for next tick.
      }
    }
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _sourceSub?.cancel();
    _sourceSub = null;
    if (!_pcmController.isClosed) _pcmController.close();
  }

  void dispose() {
    stop();
    _queue.clear();
  }
}
