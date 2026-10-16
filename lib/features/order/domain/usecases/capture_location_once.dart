import 'package:steelforce/features/order/domain/services/order_location_service.dart';

/// Not a [UseCase] — GPS capture either succeeds with a position or
/// returns null (denied/unavailable), there's no domain [Failure] to model.
class CaptureLocationOnce {
  const CaptureLocationOnce(this._service);
  final OrderLocationService _service;

  Future<({double lat, double lng})?> call() => _service.captureOnce();
}
