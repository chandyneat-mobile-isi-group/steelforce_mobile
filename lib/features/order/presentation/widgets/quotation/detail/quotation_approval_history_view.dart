import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

/// The approval trail: each action taken on the quotation, with actor and comment.
class QuotationApprovalHistoryView extends StatelessWidget {
  const QuotationApprovalHistoryView({super.key, required this.history});

  final List<QuotationApprovalHistory> history;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length,
        separatorBuilder: (_, __) => Divider(color: colors.divider, height: 1),
        itemBuilder: (context, index) {
          final record = history[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            record.action,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatDateTime(record.createdAt),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                        ],
                      ),
                      if (record.actorName != null &&
                          record.actorName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'By: ${record.actorName}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5),
                          ),
                        ),
                      ],
                      if (record.comment != null &&
                          record.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.comment!,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: context.rsp(12),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
