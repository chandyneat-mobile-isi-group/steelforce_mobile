import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/page_transition.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';

/// Opens the Quotation Builder **for a specific depot**, wired with the
/// catalog/cart/sync blocs it needs.
///
/// This is the single construction path for "quote this shop" so the guided
/// visit flow, the Route Information basket action, and the "Continue Working"
/// resume all build the quotation screen identically — with the checked-in
/// depot as context, instead of sending the rep back to a shop picker they
/// already implicitly chose by checking in.
Future<void> openQuotationForDepot(
  BuildContext context, {
  required String depotId,
  required String depotName,
}) {
  return Navigator.of(context).push(AppPageRoute<void>.sharedAxisVertical(
    settings: const RouteSettings(name: QuotationBuilderScreen.routeName),
    builder: (_) => MultiBlocProvider(
      providers: [
        // No catalog pre-load: the builder opens on the guided product
        // configurator, which fetches categories only.
        BlocProvider(create: (_) => sl<CartCubit>()..load()),
        BlocProvider(create: (_) => sl<SyncCubit>()),
      ],
      child: LocalizedBuilder(
        builder: (_) => QuotationBuilderScreen(
          // Passed twice, on purpose. `leadId` is what the cart and the saved
          // quotation have always keyed off on this path, and changing that
          // would rewrite how lines merge and how the quotation is filed — so
          // it stays exactly as it was.
          //
          // `depotId` is the same id said honestly, for everything scoped
          // to the account: pricing and promotions. Without it they read null
          // and served a rep standing in a shop they had just checked into as
          // though it were a walk-in — no price and no promotion on any card —
          // while the id sat right here in the argument.
          depotId: depotId,
          leadId: depotId,
          leadDisplayName: depotName,
        ),
      ),
    ),
  ));
}
