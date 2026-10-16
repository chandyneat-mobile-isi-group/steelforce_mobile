import 'package:steelforce/core/localization/localization_services.dart';

/// Rep-facing text for a sync failure, localized from the contract's stable
/// `errorCode` — never from the backend's `detail`, which is English, written
/// for developers, and may change without notice
/// (`docs/feature/quotation-orders/api/mobile.md`, "Errors, generally").
///
/// Keys live under `sync.errors.<Area>.<Reason>` in both language files; an
/// unknown code reads as the generic message rather than as a raw key.
String localizedSyncError(String? errorCode) {
  const generic = 'sync.errors.generic';
  if (errorCode == null || errorCode.isEmpty) return generic.tr;
  final key = 'sync.errors.$errorCode';
  final text = key.tr;
  return text == key ? generic.tr : text;
}

/// A backend `status` code as the rep should read it. The server's own
/// `statusDisplay` is not on the list/detail models this app parses, so the
/// names are held client-side under `sync.remote_status.*`; an unknown status
/// (a later phase) shows its code rather than nothing.
String localizedRemoteStatus(String status) {
  final key = 'sync.remote_status.$status';
  final text = key.tr;
  return text == key ? status : text;
}
