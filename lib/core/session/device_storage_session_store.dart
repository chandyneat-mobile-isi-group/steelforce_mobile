import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';

/// Everything a session leaves outside the encrypted database: the Hive
/// boxes, files written into the app sandbox, and downloaded images.
///
/// Moved here from `AuthBloc`, so a wipe triggered anywhere — sign-out, or a
/// different rep signing in after an expired session — clears the same set.
class DeviceStorageSessionStore implements SessionScopedStore {
  const DeviceStorageSessionStore({
    required Box<dynamic> secureBox,
    required Box<dynamic> cacheBox,
  })  : _secureBox = secureBox,
        _cacheBox = cacheBox;

  final Box<dynamic> _secureBox;
  final Box<dynamic> _cacheBox;

  /// Settings that belong to the handset, not to whoever was signed in:
  /// keeping them is why the app does not re-ask the language or replay the
  /// onboarding after every sign-out. Keys from `AppPreferences`.
  static const preservedCacheKeys = <String>{
    'onboarding_complete',
    'language_code',
    'theme_mode',
    'theme_mode_last',
    'theme_version',
  };

  /// App-private folders that hold depot-derived files: generated quotation
  /// PDFs (`core/pdf/storage`), uploaded customization drawings, and visit
  /// photos taken at a depot (the Inventory Visibility step).
  static const mediaFolders = <String>['pdf', 'drawing_cache', 'visit_photos'];

  @override
  String get debugName => 'device storage';

  @override
  Future<void> clearForSignOut() async {
    // Draft registrations and other customer PII.
    await _secureBox.clear();
    await _cacheBox.deleteAll(_cacheBox.keys
        .where((k) => !preservedCacheKeys.contains(k.toString()))
        .toList());

    for (final folder in mediaFolders) {
      await deleteAppMediaDirectory(folder);
    }

    // Avatars and product pictures, on disk and decoded in memory.
    await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}
