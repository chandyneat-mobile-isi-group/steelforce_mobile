import 'package:flutter/widgets.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';

/// Tells the App Coach a screen opened — once, when it is first inserted —
/// and otherwise renders [child] untouched.
///
/// For screens that are `StatelessWidget`s (or rebuild through a
/// `LocalizedBuilder`), where a notify in `build` would fire on every rebuild.
/// An "opened" action is never evidence that anything was saved, and outside
/// a lesson [AppCoach.notify] is a no-op.
class CoachOnOpen extends StatefulWidget {
  const CoachOnOpen({super.key, required this.action, required this.child});

  final CoachAction action;
  final Widget child;

  @override
  State<CoachOnOpen> createState() => _CoachOnOpenState();
}

class _CoachOnOpenState extends State<CoachOnOpen> {
  @override
  void initState() {
    super.initState();
    AppCoach.notify(widget.action);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
