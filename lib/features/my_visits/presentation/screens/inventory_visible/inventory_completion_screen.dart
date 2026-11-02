import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_submitted_hero.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/coach_on_open.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

class InventoryCompletionScreen extends StatelessWidget {
  const InventoryCompletionScreen({
    super.key,
    required this.outletName,
    required this.onCreateQuotation,
    required this.onEndVisit,
    this.photosUploaded = false,
    this.checkOutAction,
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

  /// True when the photos already reached the server (a planned visit), so
  /// the subtitle does not promise a later sync.
  final bool photosUploaded;

  /// Takes the place of the Complete Visit button — a planned visit ends
  /// with its own check-out, not the route visit's.
  final Widget? checkOutAction;

  @override
  Widget build(BuildContext context) => CoachOnOpen(
        action: CoachAction.openVisitCompletion,
        child: Builder(builder: _build),
      );

  Widget _build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    // While the rep types a note the mascot steps aside, so the card with
    // Complete the visit sits right above the keyboard.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // A tap anywhere off the notes closes the keyboard.
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: BrandWallpaperBody(
          style: BrandWallpaperStyle.vivid,
          child: SafeArea(
            // Scrolls once the keyboard leaves too little room, so the
            // button is never squeezed out of reach.
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(context.rw(24)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),

                        // The moment the whole step builds to: the brand mascot acts out
                        // "photo sent" — snap, upload, check. A confirmation screen has
                        // one job, so it gets the room.
                        if (!typing) ...[
                          InventorySubmittedHero(
                            size: context.rr(260),
                            semanticLabel:
                                'my_visits.inventory.completion.title'.tr,
                          ),
                          SizedBox(height: context.rh(12)),
                        ],

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
                          (photosUploaded
                                  ? 'my_visits.plans.inventory.uploaded'
                                  : 'my_visits.inventory.completion.subtitle')
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
                                'my_visits.inventory.completion.next_question'
                                    .tr,
                                style: TextStyle(
                                  fontSize: context.rsp(13.5),
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: context.rh(16)),

                              // No Create Quotation here: after the photos the visit
                              // is completed, nothing else.
                              // The one action: End Visit, or the plan's
                              // Complete the visit (its check-out).
                              checkOutAction ??
                                  CoachKeys.wrap(
                                    CoachKeys.visitComplete,
                                    child: OutlinedButton.icon(
                                      onPressed: onEndVisit,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: scheme.error,
                                        side: BorderSide(
                                            color: scheme.error
                                                .withValues(alpha: 0.5)),
                                        padding: EdgeInsets.symmetric(
                                            vertical: context.rh(14)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              context.rr(12)),
                                        ),
                                      ),
                                      icon:
                                          const Icon(Icons.stop_circle_rounded),
                                      label: Text(
                                        'my_visits.inventory.completion.complete_visit'
                                            .tr,
                                        style: TextStyle(
                                          fontSize: context.rsp(15),
                                          fontWeight: FontWeight.bold,
                                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
