final class RecipientEmail {
  const RecipientEmail._(this.value);

  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final String value;

  static RecipientEmail? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (!_pattern.hasMatch(value)) {
      return null;
    }
    return RecipientEmail._(value);
  }

  static bool isBlank(String? raw) {
    return raw == null || raw.trim().isEmpty;
  }
}
