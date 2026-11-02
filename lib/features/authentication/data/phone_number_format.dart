/// E.164 for a number as reps type it or as an account stores it:
/// `012 345 678` → `+85512345678`. An already-international number keeps its
/// own country code. Cambodian local numbers start with a leading zero.
String toE164(String input) {
  final compact = input.replaceAll(RegExp(r'[\s()-]'), '');
  if (compact.startsWith('+')) return compact;
  if (compact.startsWith('0')) return '+855${compact.substring(1)}';
  return compact;
}
