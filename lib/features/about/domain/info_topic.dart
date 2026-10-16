import 'package:flutter/material.dart';

/// One section of an information page: a heading and its bullets.
///
/// Holds **key fragments**, not text. The strings live in `assets/lang/*.json`
/// under `about.detail.<topic>.<section>`, and both the JSON and this table are
/// generated from one source, so a section can never claim more bullets than
/// the bundles actually carry.
@immutable
class InfoSection {
  const InfoSection({required this.id, required this.bulletCount});

  /// Key fragment, e.g. `s1`.
  final String id;

  /// How many `b1..bN` keys this section has. A count of one renders as a
  /// paragraph rather than a bulleted item — most policy prose is a single
  /// block, and a lone bullet reads as a formatting mistake.
  final int bulletCount;
}

/// One card on the About hub, and the detail page behind it.
@immutable
class InfoTopic {
  const InfoTopic({
    required this.id,
    required this.icon,
    required this.sections,
  });

  /// Key fragment and route argument, e.g. `privacy`.
  final String id;
  final IconData icon;
  final List<InfoSection> sections;

  String get titleKey => 'about.topics.$id.title';
  String get descKey => 'about.topics.$id.desc';
  String sectionTitleKey(InfoSection s) => 'about.detail.$id.${s.id}.title';
  String bulletKey(InfoSection s, int i) => 'about.detail.$id.${s.id}.b$i';
}

/// The topics, in the order they appear on the hub.
///
/// There is no "about" topic: what SteelForce is is two sentences, shown in
/// the hub's header (`about.detail.about.s1.b1`) rather than behind a card.
///
/// Generated alongside the localisation bundles — see the note on
/// [InfoSection]. Adding a topic means regenerating both, never editing one.
const List<InfoTopic> kInfoTopics = [
  InfoTopic(
    id: 'privacy',
    icon: Icons.lock_outline_rounded,
    sections: [
      InfoSection(id: 's1', bulletCount: 4),
      InfoSection(id: 's2', bulletCount: 4),
      InfoSection(id: 's3', bulletCount: 3),
      InfoSection(id: 's4', bulletCount: 1),
      InfoSection(id: 's5', bulletCount: 1),
      InfoSection(id: 's6', bulletCount: 1),
    ],
  ),
  InfoTopic(
    id: 'security',
    icon: Icons.verified_user_outlined,
    sections: [
      InfoSection(id: 's1', bulletCount: 3),
      InfoSection(id: 's2', bulletCount: 4),
      InfoSection(id: 's3', bulletCount: 1),
    ],
  ),
  InfoTopic(
    id: 'terms',
    icon: Icons.description_outlined,
    sections: [
      InfoSection(id: 's1', bulletCount: 1),
      InfoSection(id: 's2', bulletCount: 1),
      InfoSection(id: 's3', bulletCount: 3),
      InfoSection(id: 's4', bulletCount: 1),
      InfoSection(id: 's5', bulletCount: 1),
    ],
  ),
  InfoTopic(
    id: 'support',
    icon: Icons.support_agent_rounded,
    sections: [
      InfoSection(id: 's1', bulletCount: 1),
      InfoSection(id: 's2', bulletCount: 1),
      InfoSection(id: 's3', bulletCount: 3),
    ],
  ),
];

/// Shown in the header and footer.
///
/// A constant rather than a `package_info_plus` lookup: that package is not a
/// dependency of this project, and adding a plugin plus a platform channel to
/// read a number that already lives in `pubspec.yaml` is not a trade worth
/// making. Keep this in step with `version:` in `pubspec.yaml`.
const String kAppVersion = '1.0.0';
