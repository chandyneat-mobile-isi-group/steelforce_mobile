import 'package:flutter/material.dart';

/// Directory-level loading state used while the first depot page is read.
class DepotLoading extends StatelessWidget {
  const DepotLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}
