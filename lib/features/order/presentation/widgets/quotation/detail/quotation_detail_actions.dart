import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';

/// The buttons a quotation's status allows: submit / edit / withdraw for a
/// draft, withdraw while pending approval, convert once quoted or accepted.
class QuotationDetailActions extends StatelessWidget {
  const QuotationDetailActions({
    super.key,
    required this.detail,
    required this.isSubmitting,
    required this.isCancelling,
    required this.onEdit,
    required this.onConvertToSalesOrder,
  });

  final QuotationDetail detail;
  final bool isSubmitting;
  final bool isCancelling;
  final VoidCallback onEdit;
  final VoidCallback onConvertToSalesOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.isEditable) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => context.read<QuotationDetailCubit>().submit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit for Approval',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          SizedBox(height: context.rh(10)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('orders.quotation.edit_quotation'.tr),
            ),
          ),
          SizedBox(height: context.rh(10)),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isCancelling ? null : () => _cancel(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              child: isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Withdraw Quotation'),
            ),
          ),
        ] else if (detail.isPendingApproval) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isCancelling ? null : () => _cancel(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Withdraw from Approval'),
            ),
          ),
        ] else if (detail.status.toLowerCase() == 'quoted' ||
            detail.status.toLowerCase() == 'accepted') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConvertToSalesOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('orders.quotation.convert_to_sales_order'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await _confirmCancelDialog(context);
    if (confirmed == true && context.mounted) {
      context.read<QuotationDetailCubit>().cancel();
    }
  }

  Future<bool?> _confirmCancelDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Quotation?'),
        content: const Text(
          'Are you sure you want to cancel this quotation? This action is permanent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
