import 'package:flutter/material.dart';

/// What kind of party a non-bp-depot is.
///
/// A non-bp-depot buys ISI steel without holding a business partner record in
/// SAP. They are real trade — a sub-dealer reselling out of a dealer's yard, a
/// contractor collecting against a project — but the invoice is raised against
/// somebody else, and that somebody else is the SAP depot they are linked to.
///
/// The list is short on purpose. A representative standing in a yard has to pick
/// one in a second or two, and a longer list means the wrong one gets picked.
enum NonBpDepotKind {
  subDealer('Sub-dealer', Icons.storefront_outlined),
  contractor('Contractor', Icons.engineering_outlined),
  project('Project buyer', Icons.apartment_outlined),
  walkIn('Walk-in buyer', Icons.person_outline);

  const NonBpDepotKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A party that trades through one of our SAP depots rather than directly.
///
/// **Deliberately much smaller than [Depot].** A depot carries a credit
/// limit, payment terms, a sales area, a business-partner block and five
/// evidence slots, because SAP needs all of it before an order can be posted.
/// None of that applies here: nothing is invoiced to a non-bp-depot, so there is
/// no credit to approve, no ledger to place them in, and no ERP record to keep
/// in step. What is left is identity — who they are and how to reach them — plus
/// the one field that gives the record its purpose.
///
/// That field is [linkedDepotCode]. Without it a non-bp-depot is an orphan
/// note in a phone: sales through them land against nobody, and the dealer who
/// actually carries the receivable gets no credit for the volume. With it, a
/// visit to a sub-dealer rolls up to the dealer it belongs to.
@immutable
class NonBpDepotDemo {
  const NonBpDepotDemo({
    required this.id,
    required this.name,
    required this.kind,
    required this.phone,
    required this.location,
    required this.linkedDepotCode,
    required this.linkedDepotName,
    this.identityNumber,
    this.note,
  });

  final String id;
  final String name;
  final NonBpDepotKind kind;
  final String phone;
  final String location;

  /// Business code of the SAP depot this party trades through.
  final String linkedDepotCode;

  /// That depot's trading name, denormalised so a list row needs no lookup.
  final String linkedDepotName;

  /// National ID or business licence number, where one was shown.
  ///
  /// Optional, and the screen says so. A sub-dealer met at a roadside yard will
  /// often not produce one, and a required field here would mean the record is
  /// never created at all — which is worse than a record without an ID.
  final String? identityNumber;

  final String? note;
}

/// Sample rows for the demo. Nothing here is persisted or fetched.
const List<NonBpDepotDemo> demoNonBpDepots = [
  NonBpDepotDemo(
    id: 'nc-001',
    name: 'Sok Dara Hardware',
    kind: NonBpDepotKind.subDealer,
    phone: '012 456 789',
    location: 'Chamkar Mon, Phnom Penh',
    linkedDepotCode: 'C-100234',
    linkedDepotName: 'Mekong Steel Depot',
    identityNumber: '012345678',
    note: 'Buys roofing sheet weekly from the Mekong yard.',
  ),
  NonBpDepotDemo(
    id: 'nc-002',
    name: 'Chea Vuthy Construction',
    kind: NonBpDepotKind.contractor,
    phone: '077 221 004',
    location: 'Takhmao, Kandal',
    linkedDepotCode: 'C-100234',
    linkedDepotName: 'Mekong Steel Depot',
    note: 'Collects rebar against the Kandal housing project.',
  ),
  NonBpDepotDemo(
    id: 'nc-003',
    name: 'Borey Sunrise Phase 2',
    kind: NonBpDepotKind.project,
    phone: '096 880 112',
    location: 'Sen Sok, Phnom Penh',
    linkedDepotCode: 'C-100871',
    linkedDepotName: 'Angkor Building Supply',
    identityNumber: 'BL-2291-KH',
  ),
  NonBpDepotDemo(
    id: 'nc-004',
    name: 'Ly Sopheak',
    kind: NonBpDepotKind.walkIn,
    phone: '015 303 927',
    location: 'Battambang',
    linkedDepotCode: 'C-101502',
    linkedDepotName: 'Battambang Steel Center',
  ),
];

/// A SAP depot a non-bp-depot can be pointed at.
///
/// Stands in for the real picker, which would search the depot list already
/// held on the device. Only the two fields the link needs are modelled.
@immutable
class LinkableDepotDemo {
  const LinkableDepotDemo({
    required this.code,
    required this.name,
    required this.territory,
  });

  final String code;
  final String name;
  final String territory;
}

/// Sample SAP depots for the link picker.
const List<LinkableDepotDemo> demoLinkableDepots = [
  LinkableDepotDemo(
    code: 'C-100234',
    name: 'Mekong Steel Depot',
    territory: 'Phnom Penh Central',
  ),
  LinkableDepotDemo(
    code: 'C-100871',
    name: 'Angkor Building Supply',
    territory: 'Phnom Penh North',
  ),
  LinkableDepotDemo(
    code: 'C-101502',
    name: 'Battambang Steel Center',
    territory: 'North West',
  ),
  LinkableDepotDemo(
    code: 'C-102310',
    name: 'Sihanoukville Trading Co.',
    territory: 'Coastal',
  ),
];
