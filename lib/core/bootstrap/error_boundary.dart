import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Catches the failures that would otherwise take a screen — or the whole app —
/// down, and turns them into logged, contained events.
///
/// Nothing was installed before this: no `FlutterError.onError`, no
/// `PlatformDispatcher.onError`, no `ErrorWidget.builder`. The consequences
/// were all bad and all silent:
///
///  * A single widget throwing during build replaced the screen with Flutter's
///    error box — grey in release, with no explanation a field rep could act
///    on and no record of what happened.
///  * An uncaught error in a `Future` or `Timer` vanished entirely. Nobody
///    learned that a background sync had died.
///  * Nothing reached [AppLogger], so none of it appeared in the log a bug
///    report is built from.
///
/// This does **not** make broken code work. It makes broken code *visible* and
/// survivable: the rest of the app keeps running, and the failure is recorded
/// with its stack trace in development.
abstract final class ErrorBoundary {
  /// Installs every handler. Call once, before `runApp`.
  static void install(AppLogger logger) {
    _installFrameworkHandler(logger);
    _installPlatformHandler(logger);
    _installErrorWidget(logger);
  }

  /// Runs [body] inside a zone that reports errors escaping async callbacks.
  ///
  /// [PlatformDispatcher.onError] covers most of this on modern Flutter, but a
  /// zone still catches errors thrown from `Timer` callbacks and from
  /// completers nothing is awaiting — exactly where a background sync failure
  /// hides.
  static void runGuarded(AppLogger logger, void Function() body) {
    runZonedGuarded(body, (error, stack) {
      logger.error(
        'app.uncaught',
        error: error,
        stackTrace: stack,
        fields: {'source': 'zone'},
      );
    });
  }

  /// How many times one distinct error is reported in full before it is
  /// counted instead of repeated.
  ///
  /// A render-pipeline assertion fires on **every frame**, so an unfiltered
  /// handler emits sixty identical stack traces per second. That is not
  /// diagnosis, it is a denial of service on your own console: the first
  /// occurrence — the only one carrying useful context — scrolls away in
  /// milliseconds, and the log becomes unreadable for everything else.
  static const int _repeatsLoggedInFull = 3;

  /// Occurrences per distinct error, keyed by exception + originating library.
  static final Map<String, int> _seen = <String, int>{};

  /// Clears the de-duplication state. For tests.
  @visibleForTesting
  static void resetSeen() => _seen.clear();

  /// Build, layout and paint errors.
  static void _installFrameworkHandler(AppLogger logger) {
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      // Keyed on the message rather than the stack: the same assertion from
      // the same place produces a slightly different trace each frame, and
      // keying on that would defeat the whole point.
      final key = '${details.library}|${details.exception}';
      final count = (_seen[key] ?? 0) + 1;
      _seen[key] = count;

      if (count <= _repeatsLoggedInFull) {
        logger.error(
          'app.flutterError',
          error: details.exception,
          stackTrace: details.stack,
          fields: {
            'library': details.library,
            // The one line that says *which* widget, without dumping the tree.
            'context': details.context?.toDescription(),
            'occurrence': count,
          },
        );

        // Keep Flutter's own console dump in development — it carries the
        // widget-tree excerpt that makes a layout error diagnosable.
        // Suppressed in release, where it is noise nobody reads.
        if (kDebugMode) previous?.call(details);
        return;
      }

      // Past the threshold: still counted, never silent, but no longer
      // drowning everything else. Powers of two keep a runaway error visible
      // without it dominating the log again.
      if (count == _repeatsLoggedInFull + 1 || _isPowerOfTwo(count)) {
        logger.warning('app.flutterError.repeating', fields: {
          'library': details.library,
          'occurrences': count,
          'suppressed': true,
        });
      }
    };
  }

  static bool _isPowerOfTwo(int n) => n > 0 && (n & (n - 1)) == 0;

  /// Errors that escape the Dart isolate entirely.
  static void _installPlatformHandler(AppLogger logger) {
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.error(
        'app.uncaught',
        error: error,
        stackTrace: stack,
        fields: {'source': 'platform'},
      );
      // True = handled. Returning false lets it reach the platform and kill
      // the app, which is precisely what this exists to prevent.
      return true;
    };
  }

  /// What replaces a widget that failed to build.
  static void _installErrorWidget(AppLogger logger) {
    // In development the red box with the exception text is the most useful
    // thing on screen, so it stays exactly as Flutter ships it.
    if (kDebugMode) return;

    ErrorWidget.builder = (details) {
      // Deliberately calm and contentless. A rep in a warehouse cannot act on
      // a stack trace, and showing one invites them to photograph internals.
      // The detail is already in the log via [_installFrameworkHandler].
      return const _FailedSection();
    };
  }
}

/// Stand-in for a subtree that could not build. Sized to its parent so a
/// failure inside a list row does not resize the list.
class _FailedSection extends StatelessWidget {
  const _FailedSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Icon(
          Icons.error_outline_rounded,
          // No Theme lookup: this renders when something is already wrong, and
          // an inherited-widget read is one more thing that can throw here.
          color: const Color(0xFF9E9E9E),
          size: 24,
        ),
      ),
    );
  }
}
