/// Abstracts the actual scan hardware/UI away from the rest of the feature.
/// [MobileBarcodeScannerService] is the real `mobile_scanner`-backed
/// implementation; a manual-entry-only fake could satisfy this interface
/// just as easily for a device with no camera, with zero UI/bloc changes.
abstract interface class BarcodeScannerService {
  /// Pushes the scan UI and resolves with the decoded barcode, or `null`
  /// if the user cancelled.
  Future<String?> scan();
}
