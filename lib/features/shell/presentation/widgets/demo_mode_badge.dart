import 'package:flutter/material.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Puts [DemoModeBadge] in a strip above [child] — or returns [child]
/// untouched outside a demo build. Placed in `MaterialApp.builder`, so it is
/// on every route, sign-in included.
///
/// A strip that pushes the app down rather than a pill floating over it:
/// any floating spot covers something on some screen (centred page titles,
/// the bell and avatar, full-width bottom buttons, the offline SnackBar). The
/// strip owns the top safe-area inset, so the app below lays out exactly as
/// it would on a device whose status bar is that much taller.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
class DemoModeOverlay extends StatelessWidget {
  const DemoModeOverlay({super.key, required this.child, this.network});

  final Widget child;

  /// Injectable for tests; defaults to the demo build's registered instance.
  final DemoNetwork? network;

  @override
  Widget build(BuildContext context) {
    if (!DataSourceMode.useMocks && network == null) return child;
    return Column(
      children: [
        DemoModeBadge(network: network),
        Expanded(
          // A semantics boundary of its own: routes below raise
          // `BlockSemantics`, which drops every earlier sibling up to the
          // nearest boundary — without this, the strip would vanish from
          // screen readers.
          child: Semantics(
            container: true,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// The demo strip: "DEMO" and a dot for the simulated network, sitting under
/// the status bar.
///
/// Tapping it flips [DemoNetwork] online/offline — the presenter's way to
/// show the offline-first behaviour on stage — and confirms with a SnackBar.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
class DemoModeBadge extends StatelessWidget {
  const DemoModeBadge({super.key, this.network});

  /// Injectable for tests; defaults to the demo build's registered instance.
  final DemoNetwork? network;

  void _toggle(BuildContext context, DemoNetwork network) {
    network.toggle();
    final key = network.isOnline
        ? 'shell.demo.network_online'
        : 'shell.demo.network_offline';
    ScaffoldMessenger.maybeOf(context)
      ?..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(key.tr),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final demo = network ?? sl<DemoNetwork>();
    final topInset = MediaQuery.paddingOf(context).top;
    // Listens to the translation store too: the strip is built before the
    // first language bundle has loaded, and nothing else rebuilds it then.
    return ListenableBuilder(
      listenable: Listenable.merge([demo.online, LocalizationService.instance]),
      builder: (context, _) => _DemoStrip(
        online: demo.isOnline,
        topInset: topInset,
        onTap: () => _toggle(context, demo),
      ),
    );
  }
}

class _DemoStrip extends StatelessWidget {
  const _DemoStrip({
    required this.online,
    required this.topInset,
    required this.onTap,
  });

  final bool online;
  final double topInset;
  final VoidCallback onTap;

  /// Tall enough to hit across the full width without costing a phone a
  /// whole 48dp row.
  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: (online
              ? 'shell.demo.badge_label_online'
              : 'shell.demo.badge_label_offline')
          .tr,
      hint: 'shell.demo.badge_hint'.tr,
      excludeSemantics: true,
      // Its own Material: it sits above every Scaffold, in
      // `MaterialApp.builder`, and the ink needs one to draw on.
      child: Material(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: _height,
              width: double.infinity,
              child: Center(child: _DemoLabel(online: online)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final dot = online ? colors.success : scheme.error;
    final text = TextStyle(
      color: scheme.onInverseSurface,
      fontSize: context.rsp(11),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('shell.demo.badge'.tr, style: text),
        SizedBox(width: context.rw(10)),
        Container(
          width: context.rr(8),
          height: context.rr(8),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        SizedBox(width: context.rw(6)),
        Text(
          (online ? 'shell.demo.state_online' : 'shell.demo.state_offline').tr,
          style: text.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
      ],
    );
  }
}
