import 'nutrient.dart';

class FoodDetails {
  const FoodDetails({
    required this.id,
    required this.displayName,
    required this.category,
    required this.countryHint,
    required this.description,
    required this.servingBasis,
    required this.lastAggregatedAt,
    required this.aliases,
    required this.sourceRecords,
    required this.aggregatedNutrients,
    required this.nutrientObservations,
  });

  final String id;
  final String displayName;
  final String category;
  final String countryHint;
  final String description;
  final String servingBasis;
  final DateTime lastAggregatedAt;
  final List<String> aliases;
  final List<SourceRecordView> sourceRecords;
  final List<Nutrient> aggregatedNutrients;
  final List<NutrientObservationView> nutrientObservations;

  bool get hasProvenance =>
      sourceRecords.isNotEmpty || nutrientObservations.isNotEmpty;

  List<NutrientComparisonView> get nutrientComparisons {
    final sourceById = {for (final source in sourceRecords) source.id: source};
    final observationsByLabel = <String, List<NutrientObservationView>>{};
    for (final observation in nutrientObservations) {
      observationsByLabel
          .putIfAbsent(observation.canonicalLabel, () => [])
          .add(observation);
    }
    final labels = <String>{
      ...aggregatedNutrients.map((nutrient) => nutrient.label),
      ...observationsByLabel.keys,
    }.toList()..sort();

    return labels
        .map((label) {
          Nutrient? aggregated;
          for (final nutrient in aggregatedNutrients) {
            if (nutrient.label == label) {
              aggregated = nutrient;
              break;
            }
          }
          final observations =
              observationsByLabel[label] ?? const <NutrientObservationView>[];
          final values = observations.map((item) => item.amount).toList();
          final varianceStatus = values.isEmpty
              ? NutrientVarianceStatus.missing
              : (_hasMeaningfulVariance(values)
                    ? NutrientVarianceStatus.differs
                    : NutrientVarianceStatus.consistent);
          return NutrientComparisonView(
            canonicalLabel: label,
            aggregated: aggregated,
            observations: observations
                .map(
                  (observation) => NutrientSourceObservationView(
                    sourceRecordId: observation.sourceRecordId,
                    sourceName:
                        sourceById[observation.sourceRecordId]?.sourceName ??
                        observation.sourceRecordId,
                    country:
                        sourceById[observation.sourceRecordId]?.country ?? '',
                    amount: observation.amount,
                    unit: observation.unit,
                    originalUnit: observation.originalUnit,
                  ),
                )
                .toList(growable: false),
            varianceStatus: varianceStatus,
          );
        })
        .toList(growable: false);
  }

  bool _hasMeaningfulVariance(List<double> values) {
    if (values.length < 2) {
      return false;
    }
    final min = values.reduce((left, right) => left < right ? left : right);
    final max = values.reduce((left, right) => left > right ? left : right);
    if (max == 0) {
      return min != 0;
    }
    return ((max - min).abs() / max.abs()) > 0.2;
  }
}

enum NutrientVarianceStatus { consistent, differs, missing }

class NutrientComparisonView {
  const NutrientComparisonView({
    required this.canonicalLabel,
    required this.aggregated,
    required this.observations,
    required this.varianceStatus,
  });

  final String canonicalLabel;
  final Nutrient? aggregated;
  final List<NutrientSourceObservationView> observations;
  final NutrientVarianceStatus varianceStatus;
}

class NutrientSourceObservationView {
  const NutrientSourceObservationView({
    required this.sourceRecordId,
    required this.sourceName,
    required this.country,
    required this.amount,
    required this.unit,
    required this.originalUnit,
  });

  final String sourceRecordId;
  final String sourceName;
  final String country;
  final double amount;
  final String unit;
  final String originalUnit;
}

class SourceRecordView {
  const SourceRecordView({
    required this.id,
    required this.importerId,
    required this.sourceName,
    required this.sourceRecordId,
    required this.country,
    required this.recordTitle,
    required this.recordDescription,
    required this.fetchedAt,
    required this.sourceUpdatedAt,
    this.mergeAudit,
  });

  final String id;
  final String importerId;
  final String sourceName;
  final String sourceRecordId;
  final String country;
  final String recordTitle;
  final String recordDescription;
  final DateTime fetchedAt;
  final DateTime sourceUpdatedAt;
  final MergeAuditView? mergeAudit;
}

class NutrientObservationView {
  const NutrientObservationView({
    required this.sourceRecordId,
    required this.label,
    required this.canonicalLabel,
    required this.amount,
    required this.unit,
    required this.originalUnit,
  });

  final String sourceRecordId;
  final String label;
  final String canonicalLabel;
  final double amount;
  final String unit;
  final String originalUnit;
}

class MergeAuditView {
  const MergeAuditView({
    required this.sourceRecordId,
    required this.action,
    required this.confidence,
    required this.matchedBy,
    required this.reason,
    required this.itemAliasKey,
    required this.itemCategoryKey,
    required this.itemServingKey,
    required this.candidateEvaluations,
    required this.createdAt,
  });

  final String sourceRecordId;
  final String action;
  final double confidence;
  final String matchedBy;
  final String reason;
  final String itemAliasKey;
  final String itemCategoryKey;
  final String itemServingKey;
  final List<MergeCandidateEvaluationView> candidateEvaluations;
  final DateTime createdAt;

  bool get reusedCanonical => action == 'reuse';
}

class MergeCandidateEvaluationView {
  const MergeCandidateEvaluationView({
    required this.candidateCanonicalFoodId,
    required this.aliasMatched,
    required this.categoryMatched,
    required this.servingMatched,
    required this.nutrientSimilarity,
    required this.accepted,
    required this.reason,
  });

  final String candidateCanonicalFoodId;
  final bool aliasMatched;
  final bool categoryMatched;
  final bool servingMatched;
  final double nutrientSimilarity;
  final bool accepted;
  final String reason;
}
