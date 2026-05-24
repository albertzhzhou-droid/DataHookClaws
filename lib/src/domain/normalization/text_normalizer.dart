class TextNormalizer {
  const TextNormalizer();

  String cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String aliasKey(String raw) {
    return cleanText(raw).toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }
}
