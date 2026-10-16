import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/animations/animated_card.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/presentation/models/today_stop.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/skip_visit_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.todayStop,
    required this.onTap,
    this.onQuotationTap,
    this.onSkipSubmitted,
    this.isToday = true,
  });

  final TodayStop todayStop;
  final VoidCallback onTap;
  final VoidCallback? onQuotationTap;
  final void Function(String reason, String? photoPath)? onSkipSubmitted;
  final bool isToday;

  VisitStatus get _status => todayStop.stop.status;

  /// Status Color Schemes
  ({Color color, String label}) _getVisitStatusStyle(BuildContext context) {
    final colors = context.appColors;

    switch (_status) {
      case VisitStatus.checkedOut:
        return (color: colors.success, label: 'Visited');
      case VisitStatus.checkedIn:
        return (color: Colors.blue, label: 'In Progress');
      case VisitStatus.missed:
        return (color: Theme.of(context).colorScheme.error, label: 'Skipped');
      case VisitStatus.pending:
      default:
        return (color: colors.textSecondary, label: 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusStyle = _getVisitStatusStyle(context);
    final depot = todayStop.stop.depot;

    // Display Name formatted as KH & EN
    final khName = depot.nameKh;
    final enName = depot.name;
    final formattedOutletName =
        khName.isNotEmpty ? '$khName ($enName)' : enName;

    // Rules:
    // 1. Can only start/view detail on today's call plan
    // 2. Can only skip visits on today's call plan
    // 3. Ad-Hoc order button is accessible anytime
    final isVisitedOrSkipped =
        _status == VisitStatus.checkedOut || _status == VisitStatus.missed;
    final canSkip = isToday && !isVisitedOrSkipped;
    final canStartVisit = isToday && !isVisitedOrSkipped;

    // Retrieve channel (Wholesale/Retail) and tier (Diamond/Gold/Silver/Bronze)
    final channelTag = depot.territoryType.label;
    final tierTag = 'Silver'; // Fallback / mock field from depot entity

    // An ad hoc visit wears the brand: an Apex → Ironclad Blue rail down its
    // leading edge, a border and wash in Apex Blue, and a solid chip. A rep
    // scanning the day tells "I added this" from "the plan gave me this"
    // before reading a word — the chip alone was the same weight as the
    // territory tag beside it. Everything is theme tokens, so dark mode
    // follows without a second palette.
    final isAdHoc = todayStop.stop.isAdHoc;
    final scheme = Theme.of(context).colorScheme;
    final railWidth = context.rw(4);
    final cardRadius = context.rr(16);
    final padEnd = context.rw(16);
    final padTop = context.rh(12);

    final body = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.rw(16) + (isAdHoc ? railWidth : 0),
        padTop,
        padEnd,
        context.rh(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Outlet Name, Address & Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedOutletName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(4)),
                    Text(
                      depot.address,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.rw(12)),

              // Status pill.
              //
              // Animated because this is the one thing on the card that
              // *changes*, and it is the app's whole answer to "did my
              // visit register?". `WatchAllRoutes` pushes the new status
              // in live, so with a static pill the label simply teleports
              // from "In Progress" to "Visited" — easy to miss, and the
              // rep is left tapping Complete Visit again. The colour eases
              // and the wording cross-fades, so the change is witnessed.
              //
              // Pinned into the card's top-right corner: it keeps its place
              // in this row (so the name wraps short of it) and is shifted
              // out over the card's padding, inset by the 1px border.
              Transform.translate(
                offset: Offset(
                  (Directionality.of(context) == TextDirection.rtl ? -1 : 1) *
                      (padEnd - 1),
                  -(padTop - 1),
                ),
                child: AnimatedContainer(
                  duration: AppDurations.medium,
                  curve: AppCurves.standard,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(10),
                    vertical: context.rh(5),
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadiusDirectional.only(
                      topEnd: Radius.circular(cardRadius - 1),
                      bottomStart: Radius.circular(context.rr(12)),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDurations.medium,
                    switchInCurve: AppCurves.standard,
                    switchOutCurve: AppCurves.standard,
                    // Size-transition too, so a pill going from "Pending" to
                    // "In Progress" grows into the wider word instead of
                    // clipping it mid-fade.
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        axis: Axis.horizontal,
                        sizeFactor: animation,
                        child: child,
                      ),
                    ),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerRight,
                      children: [...previous, if (current != null) current],
                    ),
                    child: Text(
                      statusStyle.label,
                      // Keyed by the status, not the text: without a key
                      // `AnimatedSwitcher` sees one `Text` and never runs.
                      key: ValueKey(_status),
                      style: TextStyle(
                        color: statusStyle.color,
                        fontSize: context.rsp(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(6)),

          // Middle Row: Territory + Channel + Tier Tags + Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tagging Section: Territory, Wholesale/Retail, Diamond/Gold/Silver/Bronze
              Expanded(
                child: Wrap(
                  spacing: context.rw(6),
                  runSpacing: context.rh(4),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // An ad hoc visit says so, and says it first. It must
                    // never render its raw `sequence` — the backend bands
                    // these at 1001+ purely to sort them last, so showing
                    // the number would tell a rep they are on stop 1001.
                    if (isAdHoc)
                      _TagChip(
                        label: 'my_visits.ad_hoc.chip'.tr,
                        color: scheme.primary,
                        textColor: scheme.onPrimary,
                        icon: Icons.add_location_alt_rounded,
                      ),
                    // Plain text, not chips: these describe the outlet,
                    // they are not controls.
                    Text(
                      [depot.territory, channelTag, tierTag]
                          .where((part) => part.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Section
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map Preview Button
                  _ActionButton(
                    icon: Icons.map_rounded,
                    color: Colors.blue,
                    backgroundColor: Colors.blue.withValues(alpha: 0.12),
                    onTap: () async {
                      final lat = depot.latitude;
                      final lng = depot.longitude;
                      if (lat == 0.0 && lng == 0.0) return;
                      final url = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                      try {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (kDebugMode)
                          debugPrint('Could not launch Google Maps: $e');
                      }
                    },
                  ),
                  SizedBox(width: context.rw(8)),

                  // Basket Order Button — hidden when pending, or when
                  // quotations are switched off (no handler).
                  if (_status != VisitStatus.pending && onQuotationTap != null)
                    _ActionButton(
                      icon: Icons.shopping_basket_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      onTap: onQuotationTap,
                    ),

                  // Skip Visit Button — shown only when pending today
                  if (canSkip) ...[
                    SizedBox(width: context.rw(8)),
                    _ActionButton(
                      icon: Icons.cancel_rounded,
                      color: Theme.of(context).colorScheme.error,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.12),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final result = await showSkipVisitDialog(
                          context,
                          depot: depot,
                        );
                        if (result != null) {
                          onSkipSubmitted?.call(
                              result.reason, result.photoPath);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      // `AnimatedCard` rather than a bare `InkWell` over a `Container`: the
      // rest state is pixel-identical (same colour, border, radius, shadow),
      // and the card gains the press scale, ripple and shadow-settle every
      // other pressable surface in the app already has. A stop card is the
      // primary target on this screen — it should answer a finger.
      child: AnimatedCard(
        onTap: canStartVisit ? onTap : null,
        color: isAdHoc
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.04), colors.card)
            : colors.card,
        border: Border.all(
          color:
              isAdHoc ? scheme.primary.withValues(alpha: 0.35) : colors.border,
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        restShadow: colors.cardShadow,
        // A card that cannot be opened must not pretend otherwise.
        enableHoverScale: canStartVisit,
        pressedScale: canStartVisit ? AppScale.pressedCard : 1.0,
        // The card's `Material` clips to its radius, so the rail is drawn
        // edge to edge here and rounded by the card itself.
        child: isAdHoc
            ? Stack(
                children: [
                  body,
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: railWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [scheme.primary, colors.brandNavy],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : body,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    this.textColor,
    this.icon,
  });
  final String label;
  final Color color;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = textColor ?? context.appColors.textPrimary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(4),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.rsp(12), color: foreground),
            SizedBox(width: context.rw(4)),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: context.rsp(10.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // `PressScale`, not a bare `InkWell`: these sit *inside* the card's own
    // ripple, so a tap on the basket used to read as a tap on the card behind
    // it — the ripple spread across the whole surface and the button itself
    // did nothing visible. Scaling the button says which of the two nested
    // targets the finger actually hit.
    return PressScale(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        padding: EdgeInsets.all(context.rr(6)),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: context.rr(22),
          color: color,
        ),
      ),
    );
  }
}
