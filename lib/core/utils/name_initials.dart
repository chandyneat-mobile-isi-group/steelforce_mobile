/// The avatar letters for a person's name: first and last initial, upper-case.
///
/// "Dara Chan Sok" → "DS", "Dara" → "D". Null when there is no name to take
/// letters from, so each caller chooses its own placeholder.
String? nameInitials(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return null;
  final last = parts.length > 1 ? parts.last[0] : '';
  return (parts.first[0] + last).toUpperCase();
}
