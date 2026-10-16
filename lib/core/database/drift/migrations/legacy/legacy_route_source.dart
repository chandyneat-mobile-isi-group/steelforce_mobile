import 'package:steelforce/core/database/drift/migrations/legacy/legacy_sqlite_source.dart';

/// Compatibility alias kept so `LegacyRoutesImporter` and its test suite read
/// the same as before T1.5b.
///
/// The interface was generalized to [LegacySqliteSource] when T1.5b added a
/// second legacy file (`catalog.db`) with identical access needs — one
/// interface, two importers. This alias is not a deprecation shim to be cleaned
/// up later; it is the route importer's name for the thing it consumes, and it
/// costs nothing to keep while the imports are still shipping.
typedef LegacyRouteSource = LegacySqliteSource;
