import 'package:equatable/equatable.dart';

/// One row of SAP master data: a stable [code] and its human-readable [name].
///
/// Every Depot Helper endpoint returns this same shape under different field
/// names (`salesOrg`/`salesOrgName`, `disChannel`/`disChannelName`, …), so one
/// entity covers all of them — see ADR-009.
///
/// Deliberately has **no parent reference**: the Helper API exposes no foreign
/// keys, so a parent link here would be a field nothing could ever populate.
class MasterDataItem extends Equatable {
  const MasterDataItem({required this.code, required this.name});

  final String code;
  final String name;

  /// What the filter UI shows: `1000 — Sales Org Cambodia`, falling back to the
  /// bare code when SAP returns an empty description.
  String get label => name.isEmpty ? code : '$code — $name';

  /// Case-insensitive match across both fields, for dropdown search.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return code.toLowerCase().contains(q) || name.toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [code, name];
}
