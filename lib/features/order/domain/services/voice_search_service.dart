/// Captures a spoken phrase and returns it as text, so the catalog can run a
/// (vector) product search from it. Kept UI-free — the same way
/// [BarcodeScannerService] hides the scan hardware/UI — so a device with no
/// microphone (or a test) can supply a manual-entry fake with zero bloc
/// changes.
abstract interface class VoiceSearchService {
  /// Shows the listening UI, transcribes on-device speech, and resolves with
  /// the recognized query — or `null` if the user cancelled, said nothing, or
  /// speech recognition is unavailable on the device.
  Future<String?> listen();
}
