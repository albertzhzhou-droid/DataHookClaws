import '../domain/normalization/tag_normalizer.dart';
import '../domain/normalization/text_normalizer.dart';
import '../models/food_item.dart';

class FoodSearchIndex {
  FoodSearchIndex({
    TextNormalizer? textNormalizer,
    TagNormalizer? tagNormalizer,
  }) : _textNormalizer = textNormalizer ?? const TextNormalizer(),
       _tagNormalizer = tagNormalizer ?? const TagNormalizer();

  final TextNormalizer _textNormalizer;
  final TagNormalizer _tagNormalizer;

  List<IndexedFoodMatch> search({
    required List<FoodItem> items,
    required String query,
  }) {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.isEmpty) {
      return items
          .map((item) => IndexedFoodMatch(food: item, score: 0))
          .toList(growable: false);
    }

    final queryTokens = normalizedQuery.split(' ');
    final matches = <IndexedFoodMatch>[];

    for (final item in items) {
      final haystack = _indexText(item);
      var score = 0;
      for (final token in queryTokens) {
        if (token.isEmpty) {
          continue;
        }
        if (haystack.contains(token)) {
          score += 1;
        }
      }

      if (score > 0) {
        matches.add(IndexedFoodMatch(food: item, score: score));
      }
    }

    matches.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) {
        return byScore;
      }
      return left.food.name.compareTo(right.food.name);
    });

    return matches;
  }

  String _indexText(FoodItem item) {
    final tagText = _tagNormalizer.normalize(item.tags).join(' ');
    final nutrientText = item.nutrients
        .map((nutrient) => nutrient.label)
        .join(' ');
    return _normalizeQuery(
      [
        item.name,
        item.category,
        item.country,
        item.sourceName,
        item.description,
        tagText,
        nutrientText,
      ].join(' '),
    );
  }

  String _normalizeQuery(String value) {
    return _textNormalizer
        .aliasKey(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class IndexedFoodMatch {
  const IndexedFoodMatch({required this.food, required this.score});

  final FoodItem food;
  final int score;
}
