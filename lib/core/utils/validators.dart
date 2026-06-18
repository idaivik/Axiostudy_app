/// Form-field validators shared across the auth screens.
///
/// Email validation here is deliberately strict. A loose check (e.g. merely
/// looking for "@" and ".") lets typo'd and junk addresses through to Supabase
/// Auth, which then sends a confirmation email that bounces — hurting the
/// project's sender reputation and, at volume, triggering Supabase to throttle
/// our email sending.
class Validators {
  Validators._();

  /// Local-part@domain ending in a dotted TLD of at least two letters.
  /// Accepts normal addresses; rejects "foo", "a@b", "a@b.c", "user@host".
  static final RegExp _emailPattern = RegExp(
    r"^[\w.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
  );

  /// True when [email] is a structurally valid address. Note this can only
  /// catch malformed addresses — it cannot tell whether a well-formed address
  /// actually exists. Email confirmation + a custom SMTP provider remain the
  /// real defenses against bounces from fake-but-valid-looking addresses.
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || trimmed.length > 254) return false;
    return _emailPattern.hasMatch(trimmed);
  }
}
