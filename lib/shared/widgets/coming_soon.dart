import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// Opens [ComingSoonView] as a bottom sheet. "Got it" closes the sheet and
/// nothing else, so the screen underneath is left exactly as it was.
Future<void> showComingSoonSheet({
  required BuildContext context,
  String? title,
  String? message,
  String? actionLabel,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => LocalizedBuilder(
      // Not `BrandWallpaperBody`: its expanding stack would stretch the sheet
      // to full height. The pattern fills behind; the panel sets the size.
      builder: (context) => Stack(
        children: [
          const Positioned.fill(
            child: BrandWallpaperBackground(style: BrandWallpaperStyle.subtle),
          ),
          ComingSoonView(
            title: title,
            message: message,
            actionLabel: actionLabel,
            // Shrink-wrap: filling the sheet's max height would leave most of
            // a phone covered by empty surface.
            expand: false,
          ),
        ],
      ),
    ),
  );
}

/// [ComingSoonView] as a pushed page, for an entry point that would otherwise
/// open a full screen. [appBarTitle] names the feature, so the rep still sees
/// where they are; back and "Got it" both pop this route only.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    this.appBarTitle,
    this.title,
    this.message,
    this.actionLabel,
  });

  final String? appBarTitle;
  final String? title;
  final String? message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return LocalizedBuilder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: appBarTitle == null
              ? null
              : Text(
                  appBarTitle!,
                  style: TextStyle(
                    fontSize: context.rsp(17),
                    fontWeight: FontWeight.w800,
                  ),
                ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: context.appColors.canvas,
        ),
        body: BrandWallpaperBody(
          child: SafeArea(
            top: false,
            child: ComingSoonView(
              title: title,
              message: message,
              actionLabel: actionLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// The SteelForce "coming soon" panel: the brand sticker, a status label, a
/// title, one line of explanation and a single action.
///
/// Embeddable anywhere — a tab, a page, a sheet. It promises nothing it cannot
/// keep: no dates, countdowns or progress, because the app has none to show.
///
/// [onAction] defaults to `Navigator.maybePop`, which is right for a page or a
/// sheet. An embedded host (a shell tab, which must never pop the stack) passes
/// its own. The action fires once per view: a double tap cannot pop twice and
/// take the rep a screen further back than they meant to go.
class ComingSoonView extends StatefulWidget {
  const ComingSoonView({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.expand = true,
  });

  /// Null uses the shared `coming_soon.*` copy.
  final String? title;
  final String? message;
  final String? actionLabel;

  final VoidCallback? onAction;

  /// True centres the panel in all the height it is given (a page or tab);
  /// false shrink-wraps it (a sheet).
  final bool expand;

  /// The sticker never grows past this, however tall the screen.
  static const double maxAnimationHeight = 260;

  /// Readable line length on a tablet or a wide window.
  static const double maxContentWidth = 440;

  @override
  State<ComingSoonView> createState() => _ComingSoonViewState();
}

class _ComingSoonViewState extends State<ComingSoonView> {
  bool _popped = false;

  void _handleAction() {
    final onAction = widget.onAction;
    if (onAction != null) {
      onAction();
      return;
    }
    if (_popped) return;
    _popped = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = context.rh(24);
        // A third of the available height on a page, so the text and button
        // still fit above the fold on a short phone; a fixed share of the
        // screen in a sheet, whose height is not known until it is laid out.
        final available = constraints.hasBoundedHeight && widget.expand
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.75;
        final animationHeight = (available * 0.36)
            .clamp(
                context.rh(140), context.rh(ComingSoonView.maxAnimationHeight))
            .toDouble();

        final panel = ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: ComingSoonView.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decorative: the heading below says everything it does.
              ExcludeSemantics(
                child: CoachMascot(
                  animationAsset: CoachMascot.comingSoonAsset,
                  size: animationHeight,
                  animate: !reduceMotion,
                ),
              ),
              SizedBox(height: context.rh(20)),
              _StatusLabel(text: 'coming_soon.label'.tr),
              SizedBox(height: context.rh(14)),
              Semantics(
                header: true,
                child: Text(
                  widget.title ?? 'coming_soon.title'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(22),
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              SizedBox(height: context.rh(10)),
              Text(
                widget.message ?? 'coming_soon.message'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(14),
                  height: 1.5,
                ),
              ),
              SizedBox(height: context.rh(28)),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _handleAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: Size.fromHeight(context.rh(48)),
                    padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    widget.actionLabel ?? 'coming_soon.action'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            // Centres the panel when it fits and scrolls when it does not —
            // landscape, a small phone, or large accessibility text.
            constraints: BoxConstraints(
              minHeight: widget.expand && constraints.hasBoundedHeight
                  ? (constraints.maxHeight - verticalPadding * 2)
                      .clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(child: panel),
          ),
        );
      },
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(12),
        vertical: context.rh(5),
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontSize: context.rsp(11),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
