import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';

/// The 200 body of `POST /mobile/visits/ad-hoc`, parsed.
///
/// `data.stop` is the **ordinary** `RouteStop` shape the route feed already
/// sends, so it goes straight through [RouteStopModel.fromJson] — with its
/// planned window null and `visitSource: adHoc`, which is exactly why that
/// parser had to be made null-tolerant before this endpoint could be called.
class AdHocVisitResponse {
  const AdHocVisitResponse({
    required this.stop,
    required this.depot,
    required this.visitDate,
    required this.created,
  });

  final RouteStopModel stop;

  /// A full stop-info record, sent because the depot was not on the plan and
  /// so may not be in the device's current route payload at all.
  final DepotStopInfoModel depot;

  /// The day the server decided, echoed back. `YYYY-MM-DD`.
  final DateTime visitDate;

  /// False when the server replayed an earlier attempt carrying the same
  /// `clientRequestId`. Still a success.
  final bool created;

  /// [data] is the envelope's `data` object.
  factory AdHocVisitResponse.fromJson(DataMap data) {
    final depotJson = data['depot'];
    final stopJson = data['stop'];
    if (depotJson is! Map || stopJson is! Map) {
      throw const FormatException(
          'The ad hoc visit response was missing its stop or depot.');
    }

    final depot =
        DepotStopInfoModel.fromJson(depotJson.cast<String, dynamic>());

    return AdHocVisitResponse(
      stop: RouteStopModel.fromJson(
        stopJson.cast<String, dynamic>(),
        depot: depot,
      ),
      depot: depot,
      // Date-only on the wire. Parsed as local midnight to match how the rest
      // of this feature compares visit dates (`DateUtils.isSameDay` against
      // `DateTime.now()`); reading it as UTC would put the visit on yesterday
      // for the first seven hours of every Cambodian day.
      visitDate: _parseVisitDate(data['visitDate']),
      // Defaults to true: the field exists to tell a replay from a creation,
      // and a body that omits it is still a visit the rep now has.
      created: data['created'] as bool? ?? true,
    );
  }

  static DateTime _parseVisitDate(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      throw const FormatException(
          'The ad hoc visit response was missing its visit date.');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw const FormatException(
          'The ad hoc visit response carried an unreadable visit date.');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
