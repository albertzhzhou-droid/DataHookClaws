import '../domain/normalization/text_normalizer.dart';
import '../models/food_details.dart';
import '../models/food_item.dart';
import '../models/food_search_query.dart';
import '../models/food_summary.dart';
import '../models/merge_review_issue.dart';

class FoodQualityService {
  FoodQualityService({TextNormalizer? textNormalizer})
    : _textNormalizer = textNormalizer ?? const TextNormalizer();

  final TextNormalizer _textNormalizer;

  bool matchesAdvancedQuery({
    required FoodItem item,
    required FoodDetails? details,
    required FoodSearchQuery query,
  }) {
    if (!_matchesText(item, details, query.text)) {
      return false;
    }
    if (!_matchesAny(query.countries, [
      item.country,
      if (details != null) details.countryHint,
    ], details?.sourceRecords.map((source) => source.country))) {
      return false;
    }
    if (!_matchesAny(
      query.importerIds,
      const [],
      details?.sourceRecords.map((source) => source.importerId),
    )) {
      return false;
    }
    if (!_matchesAny(query.categories, [item.category, details?.category])) {
      return false;
    }
    for (final range in query.nutrientRanges) {
      if (!_matchesRange(item, details, range)) {
        return false;
      }
    }
    return true;
  }

  FoodSummary summaryFromItem(FoodItem item) {
    return FoodSummary(
      id: item.id,
      name: item.name,
      category: item.category,
      country: item.country,
      sourceSummary: item.sourceName,
      description: item.description,
      servingBasis: item.servingBasis,
      lastUpdated: item.lastUpdated,
    );
  }

  List<MergeReviewIssue> reviewIssuesForDetails(FoodDetails details) {
    final issues = <MergeReviewIssue>[];
    for (final source in details.sourceRecords) {
      final audit = source.mergeAudit;
      if (audit == null) {
        continue;
      }
      if (audit.action == 'reuse' && audit.confidence < 0.75) {
        issues.add(
          _issue(
            details: details,
            sourceRecordId: source.id,
            type: MergeReviewIssueType.lowConfidenceReuse,
            severity: MergeReviewSeverity.warning,
            reason: audit.reason,
            candidateSummary: _candidateSummary(audit.candidateEvaluations),
            createdAt: audit.createdAt,
          ),
        );
      }
      final categoryConflicts = audit.candidateEvaluations.where(
        (candidate) => candidate.aliasMatched && !candidate.categoryMatched,
      );
      for (final candidate in categoryConflicts) {
        issues.add(
          _issue(
            details: details,
            sourceRecordId: source.id,
            type: MergeReviewIssueType.categoryConflictCandidate,
            severity: MergeReviewSeverity.high,
            reason: candidate.reason,
            candidateSummary: 'Candidate ${candidate.candidateCanonicalFoodId}',
            createdAt: audit.createdAt,
            suggestedCanonicalFoodId: candidate.candidateCanonicalFoodId,
          ),
        );
      }
      if (audit.action == 'create' && audit.candidateEvaluations.isNotEmpty) {
        issues.add(
          _issue(
            details: details,
            sourceRecordId: source.id,
            type: MergeReviewIssueType.createdWithCandidates,
            severity: MergeReviewSeverity.info,
            reason: audit.reason,
            candidateSummary: _candidateSummary(audit.candidateEvaluations),
            createdAt: audit.createdAt,
          ),
        );
      }
    }

    for (final comparison in details.nutrientComparisons) {
      if (comparison.varianceStatus != NutrientVarianceStatus.differs) {
        continue;
      }
      issues.add(
        _issue(
          details: details,
          sourceRecordId: comparison.observations.isEmpty
              ? ''
              : comparison.observations.first.sourceRecordId,
          type: MergeReviewIssueType.multiSourceNutrientVariance,
          severity: MergeReviewSeverity.warning,
          reason:
              '${comparison.canonicalLabel} differs across official source observations.',
          candidateSummary: comparison.observations
              .map(
                (observation) =>
                    '${observation.sourceName}: ${observation.amount} ${observation.unit}',
              )
              .join(' | '),
          createdAt: details.lastAggregatedAt,
        ),
      );
    }

    issues.sort((left, right) {
      final severity = _severityRank(
        right.severity,
      ).compareTo(_severityRank(left.severity));
      if (severity != 0) {
        return severity;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return issues;
  }

  bool _matchesText(FoodItem item, FoodDetails? details, String query) {
    final normalized = _key(query);
    if (normalized.isEmpty) {
      return true;
    }
    final values = [
      item.name,
      item.category,
      item.country,
      item.sourceName,
      item.description,
      ...item.tags,
      if (details != null) ...[
        details.displayName,
        details.category,
        details.countryHint,
        details.description,
        ...details.aliases,
        ...details.sourceRecords.map((source) => source.recordTitle),
        ...details.sourceRecords.map((source) => source.recordDescription),
      ],
    ];
    return _key(values.join(' ')).contains(normalized);
  }

  bool _matchesAny(
    List<String> filters,
    List<String?> primaryValues, [
    Iterable<String>? secondaryValues,
  ]) {
    final normalizedFilters = filters
        .map(_key)
        .where((item) => item.isNotEmpty);
    if (normalizedFilters.isEmpty) {
      return true;
    }
    final haystack = [
      ...primaryValues.whereType<String>(),
      ...?secondaryValues,
    ].map(_key).join(' ');
    return normalizedFilters.any(haystack.contains);
  }

  bool _matchesRange(
    FoodItem item,
    FoodDetails? details,
    NutrientRangeFilter range,
  ) {
    final labelKey = _key(range.canonicalLabel);
    final observationMatches =
        details?.nutrientObservations.where(
          (observation) =>
              _key(observation.canonicalLabel) == labelKey &&
              _amountInRange(observation.amount, range),
        ) ??
        const <NutrientObservationView>[];
    if (observationMatches.isNotEmpty) {
      return true;
    }
    return item.nutrients.any(
      (nutrient) =>
          _key(nutrient.label) == labelKey &&
          _amountInRange(nutrient.amount, range),
    );
  }

  bool _amountInRange(double amount, NutrientRangeFilter range) {
    final min = range.min;
    final max = range.max;
    if (min != null && amount < min) {
      return false;
    }
    if (max != null && amount > max) {
      return false;
    }
    return true;
  }

  MergeReviewIssue _issue({
    required FoodDetails details,
    required String sourceRecordId,
    required MergeReviewIssueType type,
    required MergeReviewSeverity severity,
    required String reason,
    required String candidateSummary,
    required DateTime createdAt,
    String? suggestedCanonicalFoodId,
  }) {
    return MergeReviewIssue(
      id: '${details.id}:${sourceRecordId.isEmpty ? type.name : sourceRecordId}:${type.name}:$candidateSummary',
      canonicalFoodId: details.id,
      sourceRecordId: sourceRecordId,
      type: type,
      severity: severity,
      reason: reason,
      candidateSummary: candidateSummary,
      createdAt: createdAt,
      suggestedCanonicalFoodId: suggestedCanonicalFoodId,
    );
  }

  String _candidateSummary(List<MergeCandidateEvaluationView> candidates) {
    if (candidates.isEmpty) {
      return 'No candidates evaluated.';
    }
    return candidates
        .map(
          (candidate) =>
              '${candidate.accepted ? 'accepted' : 'rejected'} ${candidate.candidateCanonicalFoodId}: ${candidate.reason}',
        )
        .join(' | ');
  }

  int _severityRank(MergeReviewSeverity severity) {
    return switch (severity) {
      MergeReviewSeverity.info => 0,
      MergeReviewSeverity.warning => 1,
      MergeReviewSeverity.high => 2,
    };
  }

  String _key(String value) => _textNormalizer.aliasKey(value).trim();
}
