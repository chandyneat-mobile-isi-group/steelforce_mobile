import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/features/app_coach/data/models/coach_progress_model.dart';

/// Persists coach progress in the plain (non-secure) Hive cache box — the same
/// store [AppPreferences] uses. Onboarding state is not sensitive.
abstract interface class CoachLocalDataSource {
  CoachProgressModel? readProgress(int fallbackVersion);
  Future<void> writeProgress(CoachProgressModel progress);
  Future<void> clear();
}

class CoachLocalDataSourceImpl implements CoachLocalDataSource {
  const CoachLocalDataSourceImpl(this._box);
  final Box<dynamic> _box;

  static const String _key = 'app_coach_progress_v1';

  @override
  CoachProgressModel? readProgress(int fallbackVersion) {
    try {
      final raw = _box.get(_key);
      if (raw is! Map) return null;
      return CoachProgressModel.fromMap(raw, fallbackVersion);
    } catch (e) {
      // Corrupt/legacy value — treat as no progress. Never throw on read.
      debugPrint('CoachLocalDataSource: read failed — $e');
      return null;
    }
  }

  @override
  Future<void> writeProgress(CoachProgressModel progress) async {
    try {
      await _box.put(_key, progress.toMap());
    } catch (e) {
      debugPrint('CoachLocalDataSource: write failed — $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _box.delete(_key);
    } catch (e) {
      debugPrint('CoachLocalDataSource: clear failed — $e');
    }
  }
}
