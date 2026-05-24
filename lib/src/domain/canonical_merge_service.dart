import '../models/food_item.dart';
import '../models/nutrient.dart';
import 'normalization/text_normalizer.dart';

class CanonicalMergeService {
  const CanonicalMergeService({TextNormalizer? textNormalizer})
    : _textNormalizer = textNormalizer ?? const TextNormalizer();

  final TextNormalizer _textNormalizer;

  CanonicalMergeAudit decide({
    required FoodItem item,
    required List<CanonicalMergeCandidate> candidates,
  }) {
    final itemNameKey = aliasKey(item.name);
    final itemCategoryKey = categoryKey(item.category);
    final itemServingKey = servingKey(item.servingBasis);

    final evaluations = candidates
        .map(
          (candidate) => _evaluateCandidate(
            item: item,
            candidate: candidate,
            itemNameKey: itemNameKey,
            itemCategoryKey: itemCategoryKey,
            itemServingKey: itemServingKey,
          ),
        )
        .toList(growable: false);

    final exactEvaluations =
        evaluations
            .where(
              (evaluation) =>
                  evaluation.aliasMatched &&
                  evaluation.categoryMatched &&
                  evaluation.servingMatched,
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.nutrientSimilarity.compareTo(left.nutrientSimilarity),
          );

    if (exactEvaluations.isNotEmpty) {
      final best = exactEvaluations.first;
      final matchedBy = best.nutrientSimilarity > 0
          ? 'name-category-serving-nutrient'
          : 'name-category-serving';
      final reason = best.nutrientSimilarity > 0
          ? 'Exact alias/category/serving match with nutrient similarity ${best.nutrientSimilarity.toStringAsFixed(2)}.'
          : 'Exact alias/category/serving match.';

      return CanonicalMergeAudit(
        decision: CanonicalMergeDecision(
          action: CanonicalMergeAction.reuse,
          canonicalFoodId: best.canonicalFoodId,
          confidence: best.nutrientSimilarity > 0
              ? best.nutrientSimilarity
              : 0.95,
          matchedBy: matchedBy,
          reason: reason,
        ),
        itemAliasKey: itemNameKey,
        itemCategoryKey: itemCategoryKey,
        itemServingKey: itemServingKey,
        candidateEvaluations: evaluations
            .map(
              (evaluation) => evaluation.canonicalFoodId == best.canonicalFoodId
                  ? evaluation.copyWith(accepted: true, reason: reason)
                  : evaluation,
            )
            .toList(growable: false),
      );
    }

    final fallbackReason = evaluations.isEmpty
        ? 'No canonical candidates were evaluated for this source record.'
        : 'No exact canonical candidate matched alias/category/serving.';
    final canonicalFoodId = canonicalIdFor(item);
    return CanonicalMergeAudit(
      decision: CanonicalMergeDecision(
        action: CanonicalMergeAction.create,
        canonicalFoodId: canonicalFoodId,
        confidence: 1,
        matchedBy: evaluations.isEmpty ? 'no-candidates' : 'new-canonical',
        reason: fallbackReason,
      ),
      itemAliasKey: itemNameKey,
      itemCategoryKey: itemCategoryKey,
      itemServingKey: itemServingKey,
      candidateEvaluations: evaluations,
    );
  }

  String canonicalIdFor(FoodItem item) {
    return 'canonical:${aliasKey(item.name)}:${categoryKey(item.category)}:${servingKey(item.servingBasis)}';
  }

  String aliasKey(String value) => _textNormalizer.aliasKey(value);

  String categoryKey(String value) => _textNormalizer.aliasKey(value);

  String servingKey(String value) => _textNormalizer.aliasKey(value);

  CanonicalMergeCandidateEvaluation _evaluateCandidate({
    required FoodItem item,
    required CanonicalMergeCandidate candidate,
    required String itemNameKey,
    required String itemCategoryKey,
    required String itemServingKey,
  }) {
    final aliasMatched = candidate.aliasKeys.contains(itemNameKey);
    final categoryMatched = candidate.categoryKey == itemCategoryKey;
    final servingMatched = candidate.servingKey == itemServingKey;
    final nutrientSimilarity = _nutrientSimilarity(
      left: item.nutrients,
      right: candidate.nutrients,
    );
    final reason = _candidateReason(
      aliasMatched: aliasMatched,
      categoryMatched: categoryMatched,
      servingMatched: servingMatched,
      nutrientSimilarity: nutrientSimilarity,
    );

    return CanonicalMergeCandidateEvaluation(
      canonicalFoodId: candidate.canonicalFoodId,
      aliasMatched: aliasMatched,
      categoryMatched: categoryMatched,
      servingMatched: servingMatched,
      nutrientSimilarity: nutrientSimilarity,
      accepted: false,
      reason: reason,
    );
  }

  String _candidateReason({
    required bool aliasMatched,
    required bool categoryMatched,
    required bool servingMatched,
    required double nutrientSimilarity,
  }) {
    if (!aliasMatched) {
      return 'Alias key mismatch.';
    }
    if (!categoryMatched) {
      return 'Category mismatch prevented automatic merge.';
    }
    if (!servingMatched) {
      return 'Serving basis mismatch prevented automatic merge.';
    }
    if (nutrientSimilarity > 0) {
      return 'Exact alias/category/serving match with nutrient similarity ${nutrientSimilarity.toStringAsFixed(2)}.';
    }
    return 'Exact alias/category/serving match.';
  }

  double _nutrientSimilarity({
    required List<Nutrient> left,
    required List<Nutrient> right,
  }) {
    const coreLabels = {
      'Protein',
      'Fat',
      'Carbohydrate',
      'Energy',
      'Sodium',
      'Vitamin C',
    };

    final leftMap = {
      for (final nutrient in left)
        if (coreLabels.contains(nutrient.label)) nutrient.label: nutrient,
    };
    final rightMap = {
      for (final nutrient in right)
        if (coreLabels.contains(nutrient.label)) nutrient.label: nutrient,
    };

    final overlap = leftMap.keys.toSet().intersection(rightMap.keys.toSet());
    if (overlap.isEmpty) {
      return 0;
    }

    var total = 0.0;
    for (final label in overlap) {
      final leftAmount = leftMap[label]!.amount.abs();
      final rightAmount = rightMap[label]!.amount.abs();
      final maxAmount = leftAmount > rightAmount ? leftAmount : rightAmount;
      if (maxAmount == 0) {
        total += 1;
        continue;
      }
      final minAmount = leftAmount < rightAmount ? leftAmount : rightAmount;
      total += minAmount / maxAmount;
    }

    return total / overlap.length;
  }
}

enum CanonicalMergeAction { reuse, create }

class CanonicalMergeDecision {
  const CanonicalMergeDecision({
    required this.action,
    required this.canonicalFoodId,
    required this.confidence,
    required this.matchedBy,
    required this.reason,
  });

  final CanonicalMergeAction action;
  final String canonicalFoodId;
  final double confidence;
  final String matchedBy;
  final String reason;
}

class CanonicalMergeAudit {
  const CanonicalMergeAudit({
    required this.decision,
    required this.itemAliasKey,
    required this.itemCategoryKey,
    required this.itemServingKey,
    required this.candidateEvaluations,
  });

  final CanonicalMergeDecision decision;
  final String itemAliasKey;
  final String itemCategoryKey;
  final String itemServingKey;
  final List<CanonicalMergeCandidateEvaluation> candidateEvaluations;
}

class CanonicalMergeCandidate {
  const CanonicalMergeCandidate({
    required this.canonicalFoodId,
    required this.categoryKey,
    required this.servingKey,
    required this.aliasKeys,
    required this.nutrients,
  });

  final String canonicalFoodId;
  final String categoryKey;
  final String servingKey;
  final Set<String> aliasKeys;
  final List<Nutrient> nutrients;
}

class CanonicalMergeCandidateEvaluation {
  const CanonicalMergeCandidateEvaluation({
    required this.canonicalFoodId,
    required this.aliasMatched,
    required this.categoryMatched,
    required this.servingMatched,
    required this.nutrientSimilarity,
    required this.accepted,
    required this.reason,
  });

  final String canonicalFoodId;
  final bool aliasMatched;
  final bool categoryMatched;
  final bool servingMatched;
  final double nutrientSimilarity;
  final bool accepted;
  final String reason;

  CanonicalMergeCandidateEvaluation copyWith({bool? accepted, String? reason}) {
    return CanonicalMergeCandidateEvaluation(
      canonicalFoodId: canonicalFoodId,
      aliasMatched: aliasMatched,
      categoryMatched: categoryMatched,
      servingMatched: servingMatched,
      nutrientSimilarity: nutrientSimilarity,
      accepted: accepted ?? this.accepted,
      reason: reason ?? this.reason,
    );
  }
}
