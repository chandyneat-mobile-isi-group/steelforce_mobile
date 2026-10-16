import 'package:flutter/widgets.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// Rebuilds its subtree the instant the app language changes — the mechanism
/// behind the "hot reload" localization effect.
///
/// It listens to the global [LocalizationService] (a [ChangeNotifier]), so it
/// needs **no provider ancestry** and works in every route, including screens
/// pushed via a bare `MaterialPageRoute` that sit in their own overlay entry
/// and would otherwise never rebuild when the language switches.
///
/// Wrap a screen's `build` return in it:
/// ```dart
/// @override
/// Widget build(BuildContext context) => LocalizedBuilder(
///       builder: (context) => Scaffold(/* ... uses .tr ... */),
///     );
/// ```
class LocalizedBuilder extends StatelessWidget {
  const LocalizedBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder (rather than ListenableBuilder) for broad SDK
    // compatibility — both simply rebuild `builder` on notifyListeners().
    return AnimatedBuilder(
      animation: LocalizationService.instance,
      builder: (context, _) => builder(context),
    );
  }
}
