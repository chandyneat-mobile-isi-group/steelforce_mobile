import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';

/// The live check-in / check-out endpoints
/// (`check-in-check-out-mobile.md` §4–§6). Every refusal leaves as an
/// `ApiException`; the repository decides what each code means.
abstract interface class VisitCheckRemoteDataSource {
  Future<ServerVisit> checkIn(CheckInRecordModel record);
  Future<ServerVisit> checkOut(CheckOutRecordModel record);
  Future<List<NoOrderReason>> fetchCheckOutReasons();
}
