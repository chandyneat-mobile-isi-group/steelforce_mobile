/// `/files/avatars/abc` + `https://api.example.com/` →
/// `https://api.example.com/files/avatars/abc`.
///
/// The API returns some addresses — avatars — relative to its own host. An
/// already-absolute URL is returned unchanged, and null or blank stays null so
/// the caller renders its placeholder, never a stock image.
String? resolveServerUrl(String? path, String apiBaseUrl) {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  final base = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return value.startsWith('/') ? '$base$value' : '$base/$value';
}
