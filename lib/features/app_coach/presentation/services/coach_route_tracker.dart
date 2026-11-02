import 'package:flutter/widgets.dart';

/// Where the app's Navigator is, as far as the coach cares: is the shell the
/// page on top, and is a dialog or sheet over it?
///
/// The coach overlay sits above the Navigator (in `MaterialApp.builder`), so it
/// draws over every route — including dialogs. It reads this to stay out of
/// the way: the classic tour only shows while the shell is on top, and a
/// lesson's guide shrinks to a chip while a dialog or sheet is open.
@immutable
class CoachRouteInfo {
  const CoachRouteInfo({
    this.pageDepth = 0,
    this.popupOpen = false,
    this.topRouteName,
  });

  /// Page routes on the stack. 1 means the first page — the shell, for a
  /// signed-in rep — is the one on screen.
  final int pageDepth;

  /// A dialog, bottom sheet or menu is on top.
  final bool popupOpen;

  /// Name of the top page route. The app-wide coach layer also covers the
  /// splash and login routes, so depth alone cannot tell whether Home is up.
  final String? topRouteName;

  bool get shellOnTop =>
      topRouteName == '/main' && pageDepth <= 1 && !popupOpen;

  @override
  bool operator ==(Object other) =>
      other is CoachRouteInfo &&
      other.pageDepth == pageDepth &&
      other.popupOpen == popupOpen &&
      other.topRouteName == topRouteName;

  @override
  int get hashCode => Object.hash(pageDepth, popupOpen, topRouteName);
}

/// App-wide holder of [CoachRouteInfo]. One instance for the app's life;
/// every [MaterialApp] build gets a fresh [CoachRouteObserver] writing into it
/// (an observer may serve only one Navigator, and a language change or
/// sign-out rebuilds the Navigator).
class CoachRouteTracker extends ValueNotifier<CoachRouteInfo> {
  CoachRouteTracker() : super(const CoachRouteInfo());
}

class CoachRouteObserver extends NavigatorObserver {
  CoachRouteObserver(this._tracker);

  final CoachRouteTracker _tracker;
  final List<Route<dynamic>> _stack = [];

  void _publish() {
    final pages = _stack.whereType<PageRoute<dynamic>>().length;
    final popup = _stack.isNotEmpty && _stack.last is PopupRoute;
    final info = CoachRouteInfo(
      pageDepth: pages,
      popupOpen: popup,
      topRouteName: _stack.isEmpty ? null : _stack.last.settings.name,
    );
    // Navigator callbacks can arrive mid-build; publish after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tracker.value = info;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else {
      if (oldRoute != null) _stack.remove(oldRoute);
      if (newRoute != null) _stack.add(newRoute);
    }
    _publish();
  }
}
