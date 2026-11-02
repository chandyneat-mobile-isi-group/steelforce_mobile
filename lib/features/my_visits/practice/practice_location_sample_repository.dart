import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/location_sample.dart';
import 'package:steelforce/features/my_visits/domain/repositories/location_sample_repository.dart';

/// GPS samples and fraud flags for a practice lesson, held in memory.
///
/// The practice check-in runs the real fraud rules, so it can raise real
/// flags (a VPN, a written reason for a check-in without a fix). Raised on the
/// practice route they stay here: a rehearsal must not leave a fraud trail
/// against the rep. Anything on a real route goes to the real repository, and
/// once [PracticeWorld.isClosed] everything does.
class PracticeLocationSampleRepository implements LocationSampleRepository {
  PracticeLocationSampleRepository(this._real, this._world);

  final LocationSampleRepository _real;
  final PracticeWorld _world;

  final List<LocationSample> samples = [];
  final List<FraudFlag> fraudFlags = [];

  bool _practice(String routeId) =>
      !_world.isClosed && PracticeIds.isPractice(routeId);

  @override
  ResultFuture<void> recordSample(LocationSample sample) async {
    if (!_practice(sample.routeId)) return _real.recordSample(sample);
    samples.add(sample);
    return const Success(null);
  }

  @override
  ResultFuture<List<LocationSample>> fetchSamples(String routeId) async {
    if (!_practice(routeId)) return _real.fetchSamples(routeId);
    return Success(samples.where((s) => s.routeId == routeId).toList());
  }

  @override
  ResultFuture<void> recordFraudFlag(FraudFlag flag) async {
    if (!_practice(flag.routeId)) return _real.recordFraudFlag(flag);
    fraudFlags.add(flag);
    return const Success(null);
  }

  @override
  ResultFuture<List<FraudFlag>> fetchFraudFlags(String routeId) async {
    if (!_practice(routeId)) return _real.fetchFraudFlags(routeId);
    return Success(fraudFlags.where((f) => f.routeId == routeId).toList());
  }
}
