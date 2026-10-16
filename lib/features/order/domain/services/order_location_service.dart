/// One-shot GPS capture for off-visit order entry — deliberately separate
/// from `my_visits`' continuous `LocationTrackingService` (that one is
/// `routeId`-keyed and streams; this is a single snapshot for a single order).
abstract interface class OrderLocationService {
  Future<({double lat, double lng})?> captureOnce();
}
