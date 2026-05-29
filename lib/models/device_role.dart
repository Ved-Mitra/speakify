/// Device role within the Speakify network.
enum DeviceRole {
  /// The Master device captures audio from the media source
  /// and broadcasts it to all connected Slave devices.
  master,

  /// A Slave device receives the audio stream from the Master
  /// and plays it back through its speaker or headphone output.
  slave,
}
