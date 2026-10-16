import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';

/// The SAP-owned master data shown read-only on the edit sheet: the rep can
/// see it but only SAP ERP can change it.
class LockedSapSection extends StatelessWidget {
  const LockedSapSection({super.key, required this.depot});

  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: context.rr(15),
                color: colors.textSecondary,
              ),
              SizedBox(width: context.rw(6)),
              Text(
                'SAP ERP Managed Fields (Read-Only)',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          _LockedTile(label: 'SAP Depot Code', value: depot.depotCode),
          _LockedTile(label: 'SAP ID', value: depot.sapDepotId ?? 'Pending'),
          _LockedTile(
            label: 'Depot Group',
            value: depot.depotGroup ?? 'Standard',
          ),
          _LockedTile(
            label: 'Sales Org / Division',
            value: '${depot.salesOrg ?? "—"} / ${depot.division ?? "—"}',
          ),
        ],
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(11),
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: context.rsp(11),
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
