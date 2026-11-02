import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// A titled card grouping one part of a record — "Information", "Documents",
/// "Items" — on the details views of work waiting to sync. Sits on the brand
/// wallpaper, so it carries its own card surface.
class InfoSectionCard extends StatelessWidget {
  const InfoSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.count,
  });

  final IconData icon;
  final String title;

  /// Shown after the title when set ("Documents · 3").
  final int? count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rw(14),
        context.rh(12),
        context.rw(14),
        context.rh(10),
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.rr(6)),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: context.rr(16), color: scheme.primary),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    count == null ? title : '$title · $count',
                    style: TextStyle(
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          ...children,
        ],
      ),
    );
  }
}
