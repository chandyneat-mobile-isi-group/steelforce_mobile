import 'package:steelforce/features/order/domain/entities/quotation.dart';

/// Dedup rule that folds the two Home "Continue" surfaces into one when they
/// describe the *same* visit — the duplicate-navigation-state the brief warns
/// against (a visit "Continue" card next to a "Continue Quotation" draft card
/// for one Shop/Depot).
///
/// Keys on Shop/Depot **id** equality: the active visit's checked-in
/// `depotId` (from `ResumableVisitCubit`) vs the draft's `depotId`. NOTE:
/// the my_visits and depots mock datasets currently only join reliably on
/// *territory*, so ids may not match in the demo data — in that case nothing is
/// deduped and both cards render (no regression). Real backend ids make the
/// dedup take effect.

/// A draft belongs to the active visit when it's scoped to the same Shop/Depot
/// the rep is currently checked into.
bool draftBelongsToActiveVisit(Quotation draft, String? activeShopId) {
  if (activeShopId == null) return false;
  return draft.depotId != null && draft.depotId == activeShopId;
}

/// The drafts to keep on the standalone "Continue Working" card — everything
/// *not* folded into the active-visit card.
List<Quotation> standaloneDrafts(
        List<Quotation> drafts, String? activeShopId) =>
    drafts.where((d) => !draftBelongsToActiveVisit(d, activeShopId)).toList();
