import 'package:equatable/equatable.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';

/// Stable lesson ids. Persisted — never rename one.
abstract final class CoachModuleIds {
  /// The original first-run walkthrough of the Home screen.
  static const tour = 'tour';
  static const depots = 'depots';
  static const quotation = 'quotation';
  static const order = 'order';
  static const visit = 'visit';
}

/// One lesson: an ordered run of [steps] teaching a single workflow.
///
/// The [tour] runs on its own for a first-time rep. The others are started
/// from the lessons list and run as **practice**: the real screens over
/// in-memory demo data, so nothing a rep does while learning reaches the
/// database, the sync queue or the API (see `PracticeSession`).
class CoachModule extends Equatable {
  const CoachModule({
    required this.id,
    required this.titleKey,
    required this.summaryKey,
    required this.steps,
    this.practice = true,
  });

  final String id;
  final String titleKey;
  final String summaryKey;
  final List<CoachStep> steps;

  /// True: runs inside a practice session over demo data.
  final bool practice;

  /// A rep who has already done the next thing the lesson asks for (saved
  /// before the coach asked them to) moves straight on rather than being
  /// held on a step they are past. The tour keeps its strict, one-at-a-time
  /// order.
  bool get allowsSkipAhead => practice;

  @override
  List<Object?> get props => [id, steps];
}
