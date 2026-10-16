import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_unit.dart';

/// Reads of the Cambodian administrative gazetteer (ADR-003).
///
/// Every method is local-only today, because the gazetteer ships in the app
/// bundle and there is no geographic endpoint to fall back to. The interface is
/// still written as if a remote existed — `ResultFuture`, failures, an explicit
/// [ensureSeeded] — so that adding a delta sync later changes one
/// implementation and no caller. That is the difference between "offline-first"
/// and "offline-only": the domain contract does not encode the absence of a
/// server, it just never needs one.
abstract class GeoLocationRepository {
  /// Imports the bundled gazetteer if the tables are empty. Idempotent, and
  /// safe to call on every launch.
  ResultFuture<void> ensureSeeded();

  /// The children of [parentCode] at [level].
  ///
  /// One method rather than four, because the caller — the cascade — is
  /// level-agnostic by construction. [parentCode] must be null for
  /// [GeoLevel.province] and non-null for every other level; a mismatch is a
  /// programming error and fails rather than quietly returning nothing.
  ResultFuture<List<GeoUnit>> childrenOf(GeoLevel level, String? parentCode);

  /// Children of [parentCode] narrowed by [query], matching either language,
  /// the code, and (for communes) the postal code.
  ResultFuture<List<GeoUnit>> search(
    GeoLevel level,
    String? parentCode,
    String query,
  );

  /// Rebuilds a [GeoAddress] from stored codes, verifying at each step that the
  /// child really belongs to its parent.
  ///
  /// This is the read path for a saved draft or an API payload — the one place
  /// where an address arrives without having gone through the cascade, and so
  /// the one place a broken hierarchy can enter the app. It resolves as deep as
  /// the codes are consistent and stops there rather than returning a half-
  /// linked address: a district that does not belong to its province is
  /// dropped, along with everything under it.
  ResultFuture<GeoAddress> resolveAddress({
    String? provinceCode,
    String? districtCode,
    String? communeCode,
    String? villageCode,
    String? postalCode,
  });
}
