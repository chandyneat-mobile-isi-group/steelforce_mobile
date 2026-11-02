import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

/// Registers one feature's practice stand-ins into the practice scope.
///
/// Called inside [GetIt.pushNewScope], so every `register…` lands in the
/// practice scope and shadows the real registration until the scope is popped.
/// Resolve the *real* instance you wrap **before** registering its stand-in —
/// after that, `sl<T>()` answers with the stand-in.
typedef PracticeContribution = void Function(GetIt sl, PracticeWorld world);

/// A practice run of a lesson: the app's real screens over in-memory
/// stand-ins, so a rep can rehearse creating a depot, a quotation, an order or
/// a whole visit without a single record reaching the encrypted database, the
/// sync queue or the API.
///
/// ## How
///
/// Starting a session pushes a GetIt scope. Each feature contributes its own
/// stand-ins ([contribute]) — the repositories it wants to keep off disk and
/// off the network, plus its use cases re-registered over them. Blocs are
/// factories, so every screen opened during practice is built against the
/// stand-ins with no change to the screen. Ending the session pops the scope:
/// the demo data does not need to be found and deleted, it simply stops being
/// reachable.
///
/// ## The one leak, and why it is harmless
///
/// A base-scope *lazy singleton* that happens to be created for the first time
/// during practice resolves its dependencies from the practice scope and keeps
/// them after the scope is gone. Every stand-in therefore wraps the real
/// implementation and, once [PracticeWorld.isClosed], forwards to it — a
/// captured stand-in degrades to the real behaviour, never to demo data.
///
/// ## Lifetime
///
/// In memory only. A restart, a sign-out or [end] discards everything
/// practised; nothing is persisted, by design.
class PracticeSession extends ChangeNotifier {
  PracticeSession(this._sl);

  final GetIt _sl;
  final List<PracticeContribution> _contributions = [];

  static const scopeName = 'practice';

  PracticeWorld? _world;
  int _generation = 0;

  /// True while a practice scope is pushed.
  bool get isActive => _world != null;

  /// The lesson being practised, or null.
  String? get lesson => _world?.lesson;

  /// The live practice world, or null.
  PracticeWorld? get world => _world;

  /// Bumps on every start and end. Screens that hold blocs for their whole
  /// life — the shell's tabs — key on it, so they rebuild against whichever
  /// scope is now current.
  int get generation => _generation;

  /// Adds a feature's stand-ins. Called once per feature at DI time.
  void contribute(PracticeContribution contribution) =>
      _contributions.add(contribution);

  /// Starts practising [lesson], ending any session already running.
  Future<void> start(String lesson) async {
    if (isActive) await _close();
    final world = PracticeWorld._(lesson);
    _sl.pushNewScope(
      scopeName: scopeName,
      init: (sl) {
        for (final contribute in _contributions) {
          contribute(sl, world);
        }
      },
    );
    _world = world;
    _generation++;
    notifyListeners();
  }

  /// Ends practice. Idempotent.
  Future<void> end() async {
    if (!isActive) return;
    await _close();
    _generation++;
    notifyListeners();
  }

  Future<void> _close() async {
    final world = _world;
    _world = null;
    if (_sl.hasScope(scopeName)) {
      await _sl.popScopesTill(scopeName);
    }
    await world?._close();
  }
}

/// What a practice run shares across features: its lifetime, and clean-up
/// hooks for anything a stand-in put on disk (a captured practice photo).
class PracticeWorld {
  PracticeWorld._(this.lesson);

  /// The lesson being practised.
  final String lesson;

  bool _closed = false;
  final List<Future<void> Function()> _onClose = [];

  /// True once the session has ended. Stand-ins forward to the real
  /// implementation from then on — see [PracticeSession].
  bool get isClosed => _closed;

  /// Runs [cleanup] when the session ends (delete a temp file, close a
  /// stream). Failures are swallowed: clean-up must never block ending.
  void onClose(Future<void> Function() cleanup) => _onClose.add(cleanup);

  Future<void> _close() async {
    _closed = true;
    for (final cleanup in _onClose.reversed) {
      try {
        await cleanup();
      } catch (e) {
        debugPrint('PracticeWorld: clean-up failed — $e');
      }
    }
    _onClose.clear();
  }
}
