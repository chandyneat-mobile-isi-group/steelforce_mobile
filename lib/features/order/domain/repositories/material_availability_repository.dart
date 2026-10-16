import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';

/// SAP's live sellability check for a single material.
///
/// Its own repository rather than a method on `ProductFilterRepository`, and
/// the difference is not tidiness. Everything in the guided finder reads the
/// platform's own synced copy of the material master: instant, offline-safe,
/// and free to call per keystroke. This one goes through the middleware to the
/// ERP on every call. Different latency, different failure mode, different
/// rules about when it may be called — so a different interface, where those
/// rules can be stated once.
abstract interface class MaterialAvailabilityRepository {
  /// Asks SAP whether [material] may be sold into the sales area.
  ///
  /// **Call this on commitment, not on browse.** It is a live round trip; used
  /// per card on a scrolling list it would be both slow and pointless, since a
  /// rep scrolling past a material has not asked anything about it yet. The
  /// guided flow spends exactly one of these, on the material the rep picked at
  /// the SKU step.
  ///
  /// Returns a verdict, never a quantity — there is no on-hand figure anywhere
  /// in this API.
  ResultFuture<MaterialAvailability> checkAvailability(String material);
}
