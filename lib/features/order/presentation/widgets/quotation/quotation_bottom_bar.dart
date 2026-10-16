import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_state.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class QuotationBottomBar extends StatelessWidget {
  const QuotationBottomBar({
    super.key,
    required this.onSave,
    this.onBack,
    this.backLabelKey = 'common.back',
  });

  final VoidCallback onSave;
  final VoidCallback? onBack;

  /// Localisation key for the left button.
  ///
  /// A parameter rather than a hardcoded label because what that button *means*
  /// depends on how the builder was reached: inside a guided visit it ends the
  /// visit, everywhere else it simply goes back. The caller knows which.
  final String backLabelKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final items = state is CartLoaded ? state.items : const [];

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                // 30 / 70. The left button used to shrink-wrap its label,
                // which was fine for "Back" and far too narrow for a longer
                // one — the text would ellipsise while the row still had room.
                // A fixed share keeps both buttons stable whatever the label
                // or language, and Khmer runs longer than English here.
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      onPressed: onBack ?? () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border, width: 1.5),
                        // Taller than before: these are the two decisions that
                        // end the screen, tapped one-handed by someone standing
                        // in a shop.
                        padding: EdgeInsets.symmetric(vertical: context.rh(18)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        backLabelKey.tr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    flex: 7,
                    child: ElevatedButton(
                      onPressed: items.isEmpty ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accentPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: context.rh(18)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'orders.quotation.save_to_sap'.tr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
