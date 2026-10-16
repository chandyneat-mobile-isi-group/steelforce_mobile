/// Remembers the phone number the rep signs in with, so the login form can
/// fill it in next time ("Remember me").
///
/// The phone number only — **never the password**. A password kept on the
/// handset would turn a lost phone into a signed-in phone.
abstract interface class SignInMemory {
  /// The remembered number (`+855…`), or null when nothing is remembered.
  Future<String?> readPhone();

  Future<void> rememberPhone(String phone);

  Future<void> forgetPhone();
}
