import 'package:steelforce/features/my_visits/data/models/fraud_flag_model.dart';
import 'package:steelforce/features/my_visits/data/models/location_sample_model.dart';

abstract interface class LocationSampleLocalDataSource {
  Future<void> insertSample(LocationSampleModel sample);
  Future<List<LocationSampleModel>> fetchSamples(String routeId);
  Future<void> insertFraudFlag(FraudFlagModel flag);
  Future<List<FraudFlagModel>> fetchFraudFlags(String routeId);
}

// ─────────────────────────────────────────────────────────────────────────────
// The legacy sqflite `LocationSampleLocalDataSourceImpl` was removed by T1.5b.
//
// It had been retained-but-unregistered as a rollback path after the T1.5 Drift
// cutover. T1.5b removes the last reader of the plaintext `routes.db`, so the
// rollback target no longer exists — and because it imported `sqflite`, which
// has no web implementation, keeping dead code here would have blocked the web
// target permanently (`docs/blueprint/web-architecture.md`).
//
// The live implementation is `LocationSampleDriftLocalDataSource`, registered in
// `my_visits_injection.dart`. The deleted class remains in git history.
// ─────────────────────────────────────────────────────────────────────────────
