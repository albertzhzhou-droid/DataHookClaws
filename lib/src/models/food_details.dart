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
