import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';

/// The builder's flat app bar: back, the shop being quoted, and home.
class QuotationBuilderAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const QuotationBuilderAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: colorScheme.primary,
              size: context.rsp(28),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: context.rw(16)),
          child: const BackToHomeButton(),
        ),
      ],
    );
  }
}
