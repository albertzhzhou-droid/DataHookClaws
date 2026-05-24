import '../models/food_details.dart';
import '../models/food_summary.dart';

class FoodSummaryDto {
  const FoodSummaryDto({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.sourceSummary,
    required this.description,
    required this.servingBasis,
    required this.lastUpdatedIso,
  });

  final String id;
  final String name;
  final String category;
  final String country;
  final String sourceSummary;
  final String description;
  final String servingBasis;
  final String lastUpdatedIso;

  factory FoodSummaryDto.fromSummary(FoodSummary summary) {
    return FoodSummaryDto(
      id: summary.id,
      name: summary.name,
      category: summary.category,
      country: summary.country,
      sourceSummary: summary.sourceSummary,
      description: summary.description,
      servingBasis: summary.servingBasis,
      lastUpdatedIso: summary.lastUpdated.toIso8601String(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'country': country,
      'sourceSummary': sourceSummary,
      'description': description,
      'servingBasis': servingBasis,
      'lastUpdated': lastUpdatedIso,
    };
  }
}

class FoodDetailsDto {
  const FoodDetailsDto({
    required this.id,
    required this.displayName,
    required this.category,
    required this.countryHint,
    required this.description,
    required this.servingBasis,
    required this.lastAggregatedAtIso,
    required this.aliases,
    required this.sources,
    required this.aggregatedNutrients,
    required this.observationsBySource,
  });

  final String id;
  final String displayName;
  final String category;
  final String countryHint;
  final String description;
  final String servingBasis;
  final String lastAggregatedAtIso;
  final List<String> aliases;
  final List<SourceRecordDto> sources;
  final List<NutrientDto> aggregatedNutrients;
  final Map<String, List<NutrientObservationDto>> observationsBySource;

  factory FoodDetailsDto.fromDetails(FoodDetails details) {
    final observationsBySource = <String, List<NutrientObservationDto>>{};
    for (final observation in details.nutrientObservations) {
      observationsBySource.putIfAbsent(observation.sourceRecordId, () => []);
      observationsBySource[observation.sourceRecordId]!.add(
        NutrientObservationDto(
          sourceRecordId: observation.sourceRecordId,
          label: observation.label,
          canonicalLabel: observation.canonicalLabel,
          amount: observation.amount,
          unit: observation.unit,
          originalUnit: observation.originalUnit,
        ),
      );
    }

    return FoodDetailsDto(
      id: details.id,
      displayName: details.displayName,
      category: details.category,
      countryHint: details.countryHint,
      description: details.description,
      servingBasis: details.servingBasis,
      lastAggregatedAtIso: details.lastAggregatedAt.toIso8601String(),
      aliases: details.aliases,
      sources: details.sourceRecords
          .map(
            (source) => SourceRecordDto(
              id: source.id,
              importerId: source.importerId,
              sourceName: source.sourceName,
              sourceRecordId: source.sourceRecordId,
              country: source.country,
              recordTitle: source.recordTitle,
              recordDescription: source.recordDescription,
              fetchedAtIso: source.fetchedAt.toIso8601String(),
              sourceUpdatedAtIso: source.sourceUpdatedAt.toIso8601String(),
              mergeAudit: source.mergeAudit == null
                  ? null
                  : MergeAuditDto(
                      sourceRecordId: source.mergeAudit!.sourceRecordId,
                      action: source.mergeAudit!.action,
                      confidence: source.mergeAudit!.confidence,
                      matchedBy: source.mergeAudit!.matchedBy,
                      reason: source.mergeAudit!.reason,
                      itemAliasKey: source.mergeAudit!.itemAliasKey,
                      itemCategoryKey: source.mergeAudit!.itemCategoryKey,
                      itemServingKey: source.mergeAudit!.itemServingKey,
                      createdAtIso: source.mergeAudit!.createdAt
                          .toIso8601String(),
                      candidateEvaluations: source
                          .mergeAudit!
                          .candidateEvaluations
                          .map(
                            (evaluation) => MergeCandidateEvaluationDto(
                              candidateCanonicalFoodId:
                                  evaluation.candidateCanonicalFoodId,
                              aliasMatched: evaluation.aliasMatched,
                              categoryMatched: evaluation.categoryMatched,
                              servingMatched: evaluation.servingMatched,
                              nutrientSimilarity: evaluation.nutrientSimilarity,
                              accepted: evaluation.accepted,
                              reason: evaluation.reason,
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          )
          .toList(growable: false),
      aggregatedNutrients: details.aggregatedNutrients
          .map(
            (nutrient) => NutrientDto(
              label: nutrient.label,
              amount: nutrient.amount,
              unit: nutrient.unit,
            ),
          )
          .toList(growable: false),
      observationsBySource: observationsBySource,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'category': category,
      'countryHint': countryHint,
      'description': description,
      'servingBasis': servingBasis,
      'lastAggregatedAt': lastAggregatedAtIso,
      'aliases': aliases,
      'sources': sources.map((source) => source.toJson()).toList(),
      'aggregatedNutrients': aggregatedNutrients
          .map((nutrient) => nutrient.toJson())
          .toList(),
      'observationsBySource': observationsBySource.map(
        (key, value) => MapEntry(
          key,
          value.map((observation) => observation.toJson()).toList(),
        ),
      ),
    };
  }
}

class SourceRecordDto {
  const SourceRecordDto({
    required this.id,
    required this.importerId,
    required this.sourceName,
    required this.sourceRecordId,
    required this.country,
    required this.recordTitle,
    required this.recordDescription,
    required this.fetchedAtIso,
    required this.sourceUpdatedAtIso,
    required this.mergeAudit,
  });

  final String id;
  final String importerId;
  final String sourceName;
  final String sourceRecordId;
  final String country;
  final String recordTitle;
  final String recordDescription;
  final String fetchedAtIso;
  final String sourceUpdatedAtIso;
  final MergeAuditDto? mergeAudit;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'importerId': importerId,
      'sourceName': sourceName,
      'sourceRecordId': sourceRecordId,
      'country': country,
      'recordTitle': recordTitle,
      'recordDescription': recordDescription,
      'fetchedAt': fetchedAtIso,
      'sourceUpdatedAt': sourceUpdatedAtIso,
      'mergeAudit': mergeAudit?.toJson(),
    };
  }
}

class NutrientDto {
  const NutrientDto({
    required this.label,
    required this.amount,
    required this.unit,
  });

  final String label;
  final double amount;
  final String unit;

  Map<String, Object?> toJson() {
    return {'label': label, 'amount': amount, 'unit': unit};
  }
}

class NutrientObservationDto {
  const NutrientObservationDto({
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

  Map<String, Object?> toJson() {
    return {
      'sourceRecordId': sourceRecordId,
      'label': label,
      'canonicalLabel': canonicalLabel,
      'amount': amount,
      'unit': unit,
      'originalUnit': originalUnit,
    };
  }
}

class MergeAuditDto {
  const MergeAuditDto({
    required this.sourceRecordId,
    required this.action,
    required this.confidence,
    required this.matchedBy,
    required this.reason,
    required this.itemAliasKey,
    required this.itemCategoryKey,
    required this.itemServingKey,
    required this.createdAtIso,
    required this.candidateEvaluations,
  });

  final String sourceRecordId;
  final String action;
  final double confidence;
  final String matchedBy;
  final String reason;
  final String itemAliasKey;
  final String itemCategoryKey;
  final String itemServingKey;
  final String createdAtIso;
  final List<MergeCandidateEvaluationDto> candidateEvaluations;

  Map<String, Object?> toJson() {
    return {
      'sourceRecordId': sourceRecordId,
      'action': action,
      'confidence': confidence,
      'matchedBy': matchedBy,
      'reason': reason,
      'itemAliasKey': itemAliasKey,
      'itemCategoryKey': itemCategoryKey,
      'itemServingKey': itemServingKey,
      'createdAt': createdAtIso,
      'candidateEvaluations': candidateEvaluations
          .map((evaluation) => evaluation.toJson())
          .toList(),
    };
  }
}

class MergeCandidateEvaluationDto {
  const MergeCandidateEvaluationDto({
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

  Map<String, Object?> toJson() {
    return {
      'candidateCanonicalFoodId': candidateCanonicalFoodId,
      'aliasMatched': aliasMatched,
      'categoryMatched': categoryMatched,
      'servingMatched': servingMatched,
      'nutrientSimilarity': nutrientSimilarity,
      'accepted': accepted,
      'reason': reason,
    };
  }
}
