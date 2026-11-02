import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Performs a step for "Watch demo" when a tap on the step's target is not
/// enough — a product picked and given a quantity, a demo photo attached.
///
/// Returns once the action has been *started*; the coach still advances only
/// on the action the app reports when it actually succeeded.
typedef CoachDriver = Future<void> Function();

/// How "Watch demo" acts on the app: by tapping the very control a rep would
/// tap, at its position on screen, through Flutter's real gesture pipeline —
/// so autoplay goes through the same buttons, validation and dialogs as a
/// person does. It is not a recording and it is not a shortcut.
///
/// Screens add a [CoachDriver] for a target only where a single tap cannot do
/// the job, and mark the buttons of their confirmation dialogs and sheets
/// with [confirmAnchor] so autoplay can answer them.
///
/// Only ever used inside a practice lesson, over demo data.
abstract final class CoachAutopilot {
  static final Map<String, CoachDriver> _drivers = {};

  /// Anchor ids of dialog/sheet buttons autoplay may press to answer a dialog
  /// a step opened (the check-in confirmation, how the visit ended).
  static const confirmAnchor = 'autoplay_confirm';

  /// Registers [driver] for the step whose target is [anchorId]. Returns a
  /// callback that removes it — call it from `dispose`.
  static VoidCallback registerDriver(String anchorId, CoachDriver driver) {
    _drivers[anchorId] = driver;
    return () {
      if (identical(_drivers[anchorId], driver)) _drivers.remove(anchorId);
    };
  }

  static CoachDriver? driverFor(String anchorId) => _drivers[anchorId];

  static int _pointer = 9000;

  /// A real tap at [position] (global logical pixels), dispatched through
  /// the gesture binding exactly as a finger's would be.
  static Future<void> tapAt(Offset position) async {
    final binding = GestureBinding.instance;
    final pointer = ++_pointer;
    binding.handlePointerEvent(PointerDownEvent(
      pointer: pointer,
      position: position,
      kind: PointerDeviceKind.touch,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    binding.handlePointerEvent(PointerUpEvent(
      pointer: pointer,
      position: position,
      kind: PointerDeviceKind.touch,
    ));
  }

  /// Clears every driver. Tests only.
  @visibleForTesting
  static void reset() => _drivers.clear();
}
