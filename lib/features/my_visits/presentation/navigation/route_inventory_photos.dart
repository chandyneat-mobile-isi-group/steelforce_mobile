import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart';
import 'package:steelforce/core/usecase/usecase.dart' show NoParams;
import 'package:steelforce/features/my_visits/domain/entities/visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/add_visit_photo.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

/// Caption that marks a visit photo as the Inventory Visibility capture.
const String inventoryPhotoCaption = 'Inventory visibility';

/// App-private folder for visit photos. Wiped on sign-out by
/// `DeviceStorageSessionStore.mediaFolders`; rename both together.
const String visitPhotoFolder = 'visit_photos';

/// Stores the three inventory photos as visit photos on this stop.
///
/// It goes into local visit storage first and reaches the server in the
/// stop's next visit push, with the check-out and the other captures. No
/// network is needed here.
///
/// The image is copied into the app's documents folder first: the picker's
/// own file lives in a cache the OS may clear before the push runs.
///
/// A photo that cannot be tied to a stop is not saved, and the skip is
/// logged. A photo with no stop is not evidence of anything. Throws when the
/// local write fails, so the screen keeps the rep on this step.
Future<void> saveRouteInventoryPhotos({
  required String depotId,
  String? stopId,
  required List<InventoryPhotoCapture> photos,
}) async {
  final logger = sl.isRegistered<AppLogger>() ? sl<AppLogger>() : null;

  String? resolvedStopId = stopId;
  if (resolvedStopId == null) {
    final result = await sl<GetActiveWorkflow>()(const NoParams());
    final workflow = result.when(success: (w) => w, failure: (_) => null);
    resolvedStopId = workflow?.currentStopId;
  }
  if (resolvedStopId == null) {
    logger?.warning('visit.inventory_photo.not_persisted', fields: {
      'reason': 'noStop',
      'depotId': depotId,
    });
    return;
  }

  for (var index = 0; index < photos.length; index++) {
    final capture = photos[index];
    final stamp = capture.takenAt.microsecondsSinceEpoch;
    final fileName = 'inventory_${index + 1}_$stamp.jpg';
    // Web has no app folder: the picker's blob URL is the only handle there.
    final folder = await appMediaDirectory(visitPhotoFolder);
    final path = folder == null
        ? capture.photo.path
        : await copyCapturedFile(capture.photo.path,
            targetDirectory: folder, fileName: fileName);

    final result = await sl<AddVisitPhoto>()(VisitPhoto(
      id: '$stamp-inventory-${index + 1}',
      stopId: resolvedStopId,
      url: path,
      caption: '$inventoryPhotoCaption ${index + 1}/${photos.length}',
      takenAt: capture.takenAt,
    ));
    result.when(
      success: (_) {},
      failure: (f) =>
          throw StateError('inventory photo not saved: ${f.message}'),
    );
  }
}
