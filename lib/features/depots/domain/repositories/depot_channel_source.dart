import 'package:steelforce/core/utils/typedefs.dart';

/// A depot's channel as the depots API sent it, by its code — or, for a
/// Non-BP depot, its id — from the depots held on this device.
abstract interface class DepotChannelSource {
  ResultFuture<String?> channelOf({String? depotCode, String? depotId});
}
