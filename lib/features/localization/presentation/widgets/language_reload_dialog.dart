import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/localization/domain/entities/language_entity.dart';

/// Confirmation shown before switching the app language.
///
/// Switching tears down and recreates the whole `MaterialApp` (see `app.dart`)
/// so every screen — including data already on screen — comes back in the new
/// language. That reload is worth a heads-up: the user confirms, then the
/// switch itself performs the "hot reload".
///
/// Returns `true` when the user confirmed the reload.
Future<bool> showLanguageReloadConfirmDialog(
  BuildContext context,
  LanguageEntity target,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text('language.confirm_title'.tr),
        content: Text(
          'language.confirm_body'.trParams({'language': target.nameKey.tr}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('language.reload_apply'.tr),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
