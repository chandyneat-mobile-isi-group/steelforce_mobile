import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/session/session_scoped_store.dart';

/// Ends any practice run on sign-out, so the next rep never opens the app into
/// someone else's practice — and so the stores cleared after this one reach
/// the real data rather than practice stand-ins.
class PracticeSessionScopedStore implements SessionScopedStore {
  const PracticeSessionScopedStore(this._session);

  final PracticeSession _session;

  @override
  String get debugName => 'practice';

  @override
  Future<void> clearForSignOut() => _session.end();
}
