import 'text_normalizer.dart';

class TagNormalizer {
  const TagNormalizer({this.textNormalizer = const TextNormalizer()});

  final TextNormalizer textNormalizer;

  List<String> normalize(List<String> tags) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final tag in tags) {
      final cleaned = textNormalizer.cleanText(tag).toLowerCase();
      if (cleaned.isEmpty || seen.contains(cleaned)) {
        continue;
      }
      seen.add(cleaned);
      normalized.add(cleaned);
    }

    return normalized;
  }
}
