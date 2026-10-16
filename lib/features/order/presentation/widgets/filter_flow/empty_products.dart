import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The guided flow's placeholder for "there is nothing here *yet*, and here is
/// what to do about it".
///
/// Every stage that can be empty routes through this rather than rendering a
/// blank container, so the rep is never looking at an unexplained void: before
/// a category is chosen, between steps, and when a complete filter genuinely
/// matches no stock.
class EmptyProducts extends StatelessWidget {
  const EmptyProducts({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  /// "Choose a product category to begin."
  const EmptyProducts.chooseCategory({
    Key? key,
    required String title,
    String? message,
  }) : this(
          key: key,
          icon: Icons.category_outlined,
          title: title,
          message: message,
        );

  /// "Select a product family."
  const EmptyProducts.chooseFamily({
    Key? key,
    required String title,
    String? message,
  }) : this(
          key: key,
          icon: Icons.account_tree_outlined,
          title: title,
          message: message,
        );

  /// "Complete filters to view products."
  const EmptyProducts.completeFilters({
    Key? key,
    required String title,
    String? message,
  }) : this(
          key: key,
          icon: Icons.tune_rounded,
          title: title,
          message: message,
        );

  /// A finished filter that matched nothing — distinct from the above, because
  /// the answer here is "change something", not "keep going".
  const EmptyProducts.noResults({
    Key? key,
    required String title,
    String? message,
    Widget? action,
  }) : this(
          key: key,
          icon: Icons.search_off_rounded,
          title: title,
          message: message,
          action: action,
        );

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Tightens the vertical rhythm for use inside an embedded panel rather than
  /// a full screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final pad = compact ? 20.0 : 36.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: pad, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(icon,
                size: compact ? 26 : 32,
                color: scheme.primary.withValues(alpha: 0.75)),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: compact ? 13.5 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: context.rh(6)),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: compact ? 11.5 : 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: context.rh(16)),
            action!,
          ],
        ],
      ),
    );
  }
}
