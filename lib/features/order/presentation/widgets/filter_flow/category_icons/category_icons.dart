// GENERATED — category_icons.dart
// Maps a catalogue code to its asset and family. Keep codes identical to the
// material master so a new code fails loudly instead of silently drawing a box.

import 'category_icon_tokens.dart';

class CategoryIconSpec {
  const CategoryIconSpec(this.label, this.family, this.asset);
  final String label;
  final CategoryFamily family;
  final String asset;
  String get activeAsset => asset.replaceFirst('.svg', '_active.svg');
}

const String _base = 'assets/images/icons/categories-icon/svg';

const Map<String, CategoryIconSpec> categoryIcons = {
  'galvanized-coil-semi': CategoryIconSpec('Galvanized Coil (Semi-Finished)',
      CategoryFamily.semi, '$_base/galvanized-coil-semi.svg'),
  'pipe': CategoryIconSpec('Pipe', CategoryFamily.product, '$_base/pipe.svg'),
  'pre-painted-coil-raw': CategoryIconSpec('Pre-Painted Coil (Raw)',
      CategoryFamily.raw, '$_base/pre-painted-coil-raw.svg'),
  'reinforcement-bar-traded': CategoryIconSpec('Reinforcement Bar (Traded)',
      CategoryFamily.product, '$_base/reinforcement-bar-traded.svg'),
  'pre-painted-coil-semi': CategoryIconSpec('Pre-Painted Coil (Semi-Finished)',
      CategoryFamily.semi, '$_base/pre-painted-coil-semi.svg'),
  'cold-formed-sections': CategoryIconSpec('Cold Formed Sections',
      CategoryFamily.product, '$_base/cold-formed-sections.svg'),
  'galvanized-steel': CategoryIconSpec('Galvanized Steel',
      CategoryFamily.product, '$_base/galvanized-steel.svg'),
  'profile-roofing': CategoryIconSpec(
      'Profile Roofing', CategoryFamily.product, '$_base/profile-roofing.svg'),
  'i-beam-traded': CategoryIconSpec(
      'I-Beam (Traded)', CategoryFamily.product, '$_base/i-beam-traded.svg'),
  'roofing-accessories': CategoryIconSpec('Roofing Accessories',
      CategoryFamily.product, '$_base/roofing-accessories.svg'),
  'h-beam-traded': CategoryIconSpec(
      'H-Beam (Traded)', CategoryFamily.product, '$_base/h-beam-traded.svg'),
  'steel-sheet': CategoryIconSpec(
      'Steel Sheet', CategoryFamily.product, '$_base/steel-sheet.svg'),
  'galvalume-steel-coil': CategoryIconSpec('Galvalume Steel Coil',
      CategoryFamily.product, '$_base/galvalume-steel-coil.svg'),
  'sp-mech':
      CategoryIconSpec('SP-MECH', CategoryFamily.part, '$_base/sp-mech.svg'),
  'mp-mech':
      CategoryIconSpec('MP-MECH', CategoryFamily.part, '$_base/mp-mech.svg'),
  'sp-elec':
      CategoryIconSpec('SP-ELEC', CategoryFamily.part, '$_base/sp-elec.svg'),
  'ep-elec':
      CategoryIconSpec('EP-ELEC', CategoryFamily.part, '$_base/ep-elec.svg'),
  'ft-scheider': CategoryIconSpec(
      'FT-SCHEIDER', CategoryFamily.fitting, '$_base/ft-scheider.svg'),
  'ft-board': CategoryIconSpec(
      'FT-BOARD', CategoryFamily.fitting, '$_base/ft-board.svg'),
  'ft-cable': CategoryIconSpec(
      'FT-CABLE', CategoryFamily.fitting, '$_base/ft-cable.svg'),
  'ft-rf-screw': CategoryIconSpec(
      'FT-RF-SCREW', CategoryFamily.fitting, '$_base/ft-rf-screw.svg'),
  'ft-tran-sheet': CategoryIconSpec(
      'FT-TRAN-SHEET', CategoryFamily.fitting, '$_base/ft-tran-sheet.svg'),
  'ft-oth':
      CategoryIconSpec('FT-OTH', CategoryFamily.fitting, '$_base/ft-oth.svg'),
  'rm-gi': CategoryIconSpec('RM-GI', CategoryFamily.raw, '$_base/rm-gi.svg'),
  'rm-gl': CategoryIconSpec('RM-GL', CategoryFamily.raw, '$_base/rm-gl.svg'),
  'rm-crc': CategoryIconSpec('RM-CRC', CategoryFamily.raw, '$_base/rm-crc.svg'),
  'rm-ss': CategoryIconSpec('RM-SS', CategoryFamily.raw, '$_base/rm-ss.svg'),
  'rm-mh': CategoryIconSpec('RM-MH', CategoryFamily.raw, '$_base/rm-mh.svg'),
  'rm-tile-adhesiv': CategoryIconSpec(
      'RM-Tile Adhesive', CategoryFamily.raw, '$_base/rm-tile-adhesiv.svg'),
  'rm-starcode': CategoryIconSpec(
      'RM-STARCODE', CategoryFamily.raw, '$_base/rm-starcode.svg'),
  'sfg-gs':
      CategoryIconSpec('SFG-GS', CategoryFamily.semi, '$_base/sfg-gs.svg'),
  'sfg-gl':
      CategoryIconSpec('SFG-GL', CategoryFamily.semi, '$_base/sfg-gl.svg'),
  'sfg-crc':
      CategoryIconSpec('SFG-CRC', CategoryFamily.semi, '$_base/sfg-crc.svg'),
  'sfg-ss':
      CategoryIconSpec('SFG-SS', CategoryFamily.semi, '$_base/sfg-ss.svg'),
  'sfg-mh':
      CategoryIconSpec('SFG-MH', CategoryFamily.semi, '$_base/sfg-mh.svg'),
  'sfg-oth':
      CategoryIconSpec('SFG-OTH', CategoryFamily.semi, '$_base/sfg-oth.svg'),
  'fg-sc':
      CategoryIconSpec('FG-SC', CategoryFamily.finished, '$_base/fg-sc.svg'),
  'fg-mh':
      CategoryIconSpec('FG-MH', CategoryFamily.finished, '$_base/fg-mh.svg'),
  'fg-gh':
      CategoryIconSpec('FG-GH', CategoryFamily.finished, '$_base/fg-gh.svg'),
  'fg-pt':
      CategoryIconSpec('FG-PT', CategoryFamily.finished, '$_base/fg-pt.svg'),
  'fg-cfp-light-gauge-steel': CategoryIconSpec('FG-CFP Light Gauge Steel',
      CategoryFamily.finished, '$_base/fg-cfp-light-gauge-steel.svg'),
  'gen-supp-oper': CategoryIconSpec(
      'GEN-SUPP-OPER', CategoryFamily.supply, '$_base/gen-supp-oper.svg'),
  'gen-supp-hr-adm': CategoryIconSpec(
      'GEN-SUPP-HR-ADM', CategoryFamily.supply, '$_base/gen-supp-hr-adm.svg'),
  'gen-supp-mrk': CategoryIconSpec(
      'GEN-SUPP-MRK', CategoryFamily.supply, '$_base/gen-supp-mrk.svg'),
  'cm-com':
      CategoryIconSpec('CM-COM', CategoryFamily.misc, '$_base/cm-com.svg'),
  'scrap': CategoryIconSpec('SCRAP', CategoryFamily.misc, '$_base/scrap.svg'),
  'services':
      CategoryIconSpec('SERVICES', CategoryFamily.misc, '$_base/services.svg'),
  'others':
      CategoryIconSpec('OTHERS', CategoryFamily.misc, '$_base/others.svg'),
};

/// Falls back to the catch-all rather than throwing in a production grid.
CategoryIconSpec specFor(String key, {String? name}) {
  final k = key.toLowerCase();
  if (categoryIcons.containsKey(k)) return categoryIcons[k]!;

  if (name != null) {
    final n = name.toLowerCase();
    for (final spec in categoryIcons.values) {
      if (spec.label.toLowerCase() == n) return spec;
    }

    // Fuzzy matching similar to old _iconFor fallback
    if (n.contains('tile') || n.contains('wave') || n.contains('roof'))
      return categoryIcons['profile-roofing']!;
    if (n.contains('deck') ||
        n.contains('panel') ||
        n.contains('flat') ||
        n.contains('sheet')) return categoryIcons['steel-sheet']!;
    if (n.contains('truss') || n.contains('palm') || n.contains('inno'))
      return categoryIcons['cold-formed-sections']!;
    if (n.contains('gutter') ||
        n.contains('flashing') ||
        n.contains('ridge') ||
        n.contains('cap')) return categoryIcons['roofing-accessories']!;
    if (n.contains('screw') || n.contains('bolt') || n.contains('fastener'))
      return categoryIcons['ft-rf-screw']!;
    if (n.contains('square') ||
        n.contains('box pipe') ||
        n.contains('pipe') ||
        n.contains('tube')) return categoryIcons['pipe']!;
    if (n.contains('h-beam') || n.contains('i-beam') || n.contains('beam'))
      return categoryIcons['h-beam-traded']!;
    if (n.contains('rebar') ||
        n.contains('deformed') ||
        n.contains('bar') ||
        n.contains('rod')) return categoryIcons['reinforcement-bar-traded']!;
    if (n.contains('coil') || n.contains('roll'))
      return categoryIcons['galvanized-coil-semi']!;
  }

  // Fallback fuzzy key matching
  for (final entry in categoryIcons.entries) {
    if (k.contains(entry.key) || entry.key.contains(k)) {
      return entry.value;
    }
  }

  return categoryIcons['others']!;
}
