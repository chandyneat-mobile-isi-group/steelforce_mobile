import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/lookup_depot_by_code.dart';
import 'package:steelforce/features/depots/presentation/screens/depot_detail_screen.dart';

/// The platform id of the depot with [depotCode]: the rep's local book
/// first, then the server's by-code lookup. Null when neither knows it.
Future<String?> resolveDepotIdByCode(String? depotCode) async {
  final code = depotCode?.trim() ?? '';
  if (code.isEmpty) return null;

  final local = await sl<BrowseDepots>()(
      BrowseDepotsParams(page: 0, pageSize: 20, query: code));
  if (local case Success(:final data)) {
    for (final depot in data.items) {
      if (depot.depotCode.trim() == code) return depot.id;
    }
  }

  final remote = await sl<LookupDepotByCode>()(code);
  return switch (remote) {
    Success(data: DepotCodeFound(:final depot)) => depot.id,
    _ => null,
  };
}

/// Opens the details of the depot with [depotCode] — a supplier named on
/// another depot, say. Says so when no depot has that code: a branch or a
/// factory supplies too, and has no depot page.
Future<void> openDepotByCode(BuildContext context, String depotCode) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final id = await resolveDepotIdByCode(depotCode);
  if (id == null) {
    messenger.showSnackBar(
        SnackBar(content: Text('depots.detail.depot_not_found'.tr)));
    return;
  }
  await navigator.push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: DepotDetailScreen.routeName),
    builder: (_) => DepotDetailScreen(depotId: id),
  ));
}
