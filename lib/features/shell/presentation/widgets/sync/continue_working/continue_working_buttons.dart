import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_actions.dart';

/// Tactile 3D Filled Action Button — the primary ("Continue") action on the
/// "Continue Working" card and drafts sheet.
class ContinueWorkingFilledButton extends StatelessWidget {
  const ContinueWorkingFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(10)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.35),
            blurRadius: context.rr(6),
            offset: Offset(0, context.rh(3)),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: themeColor,
          padding: EdgeInsets.symmetric(vertical: context.rh(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rr(10)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Tactile 3D Outlined Action Button — the secondary ("Submit") action on the
/// "Continue Working" card and drafts sheet.
class ContinueWorkingOutlinedButton extends StatelessWidget {
  const ContinueWorkingOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: context.rr(4),
            offset: Offset(0, context.rh(2)),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: themeColor,
          backgroundColor: scheme.surface,
          side: BorderSide(
            color: themeColor.withValues(alpha: 0.8),
            width: 1.2,
          ),
          padding: EdgeInsets.symmetric(vertical: context.rh(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rr(10)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Small round "x" in the single-draft card header; asks before discarding.
class ContinueWorkingDiscardButton extends StatelessWidget {
  const ContinueWorkingDiscardButton({super.key, required this.draft});
  final Quotation draft;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => confirmDiscardDraft(context, draft),
      borderRadius: BorderRadius.circular(context.rr(20)),
      child: Container(
        padding: EdgeInsets.all(context.rr(4)),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.appColors.textSecondary.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.close_rounded,
          size: context.rsp(16),
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}
