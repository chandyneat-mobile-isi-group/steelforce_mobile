import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

class InventoryCompletionScreen extends StatelessWidget {
  const InventoryCompletionScreen({
    super.key,
    required this.outletName,
    required this.onCreateQuotation,
    required this.onEndVisit,
    this.showCreateQuotation = true,
  });

  /// `RouteSettings.name`, and the resume key for this step.
  ///
  /// Without an identity of its own this screen was invisible to the resume
  /// dispatcher: the pointer still read "inventory audit", so a rep who
  /// submitted the count and then left was sent back to walk the racks a
  /// second time. Recording the completion step is what makes finished work
  /// stay finished.
  static const String routeName = 'my-visits-inventory-completion';

  final String outletName;
  final VoidCallback onCreateQuotation;
  final VoidCallback onEndVisit;

  /// Hides Create Quotation without removing it, for a build that should
  /// end the visit here.
  final bool showCreateQuotation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.rw(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // The moment the whole step builds to: the brand mascot acts out
              // "photo sent" — snap, upload, check. A confirmation screen has
              // one job, so it gets the room.
              _SubmittedHero(
                size: context.rr(260),
                semanticLabel: 'my_visits.inventory.completion.title'.tr,
              ),
              SizedBox(height: context.rh(12)),

              // Success Heading
              Text(
                'my_visits.inventory.completion.title'.tr,
                style: TextStyle(
                  fontSize: context.rsp(20),
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rh(8)),
              Text(
                // `trParams`, not string interpolation: the outlet name sits
                // in a different position in Khmer, and a concatenated
                // sentence cannot be reordered by a translator.
                'my_visits.inventory.completion.subtitle'
                    .trParams({'outlet': outletName}),
                style: TextStyle(
                  fontSize: context.rsp(13),
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Decision Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(context.rw(16)),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(context.rr(16)),
                  border: Border.all(color: colors.border),
                  boxShadow: colors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'my_visits.inventory.completion.next_question'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(13.5),
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.rh(16)),

                    // Primary Action 1: Create Quotation
                    if (showCreateQuotation) ...[
                      ElevatedButton.icon(
                        onPressed: onCreateQuotation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding:
                              EdgeInsets.symmetric(vertical: context.rh(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rr(12)),
                          ),
                        ),
                        icon: const Icon(Icons.request_quote_rounded),
                        label: Text(
                          // Reused rather than duplicated: the Route Information
                          // screen already ships this exact action label, and two
                          // keys for one button is how the two drift apart.
                          'my_visits.route_info.create_quotation'.tr,
                          style: TextStyle(
                            fontSize: context.rsp(15),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: context.rh(10)),
                    ],

                    // Primary Action 2: End Visit
                    OutlinedButton.icon(
                      onPressed: onEndVisit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.5)),
                        padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rr(12)),
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: Text(
                        'my_visits.inventory.completion.complete_visit'.tr,
                        style: TextStyle(
                          fontSize: context.rsp(15),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The SteelForce mascot acting out the result, on a flat brand-tint stage.
///
/// The sticker tells the whole story without words, so it reads the same in
/// Khmer and English: the mascot snaps a photo on its phone, the photo flies
/// up into its speech bubble, an upload bar fills, a green check lands and
/// the mascot hops. It then plays one calm idle pass and holds — a
/// confirmation screen is read, not watched. Reduced motion shows the held,
/// finished frame (photo in the bubble, check visible).
class _SubmittedHero extends StatelessWidget {
  const _SubmittedHero({required this.size, required this.semanticLabel});

  /// Height of the hero box; the mascot fills it, the stage sits behind.
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final stage = size * 0.62;

    return Semantics(
      // One announcement for the whole picture; the mascot itself is
      // decorative and a rep should hear the result, not "animation".
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Stage behind the robot's body, low enough that its shadow sits
            // on it and clear of the speech bubble at upper-right.
            Align(
              alignment: const Alignment(-0.1, 0.55),
              child: Container(
                width: stage,
                height: stage,
                decoration: BoxDecoration(
                  color: colors.surfaceStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            CoachMascot(
              animationAsset: CoachMascot.inventorySuccessAsset,
              mood: CoachMood.cheer,
              size: size,
              loop: false,
              animate: !reduceMotion,
            ),
          ],
        ),
      ),
    );
  }
}
