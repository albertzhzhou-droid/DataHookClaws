import 'package:data_hook_claws/src/domain/food_quality_service.dart';
import 'package:data_hook_claws/src/models/food_details.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generated review IDs are versioned identities without nutrient collisions',
    () {
      final issues = FoodQualityService().reviewIssuesForDetails(
        _detailsWithAllIssueTypes(),
      );
      final identities = issues
          .map((issue) => MergeReviewIssueIdentity.tryDecode(issue.id))
          .toList(growable: false);

      expect(identities, everyElement(isNotNull));
      expect(issues.map((issue) => issue.id).toSet(), hasLength(issues.length));
      expect(
        identities.whereType<MergeReviewIssueIdentity>().map(
          (item) => item.type,
        ),
        containsAll(MergeReviewIssueType.values),
      );

      final nutrientIssues = issues
          .where(
            (issue) =>
                issue.type == MergeReviewIssueType.multiSourceNutrientVariance,
          )
          .toList(growable: false);
      expect(nutrientIssues, hasLength(2));
      expect(
        nutrientIssues.map((issue) => issue.candidateSummary).toSet(),
        hasLength(1),
      );
      final nutrientIdentities = nutrientIssues
          .map((issue) => MergeReviewIssueIdentity.tryDecode(issue.id)!)
          .toList(growable: false);
      expect(
        nutrientIdentities.map((identity) => identity.sourceRecordId).toSet(),
        {''},
      );
      expect(
        nutrientIdentities.map((identity) => identity.subjectKey).toSet(),
        {'nutrient:Fat:α|β', 'nutrient:Protein:α|β'},
      );

      final categoryIdentities = issues
          .where(
            (issue) =>
                issue.type == MergeReviewIssueType.categoryConflictCandidate,
          )
          .map((issue) => MergeReviewIssueIdentity.tryDecode(issue.id)!)
          .toList(growable: false);
      expect(
        categoryIdentities.map((identity) => identity.subjectKey).toSet(),
        {'candidate:canonical:目标|一', 'candidate:canonical:目标|二'},
      );
    },
  );

  test(
    'generated IDs ignore mutable review evidence and observation order',
    () {
      final service = FoodQualityService();
      final baseline = service.reviewIssuesForDetails(
        _detailsWithAllIssueTypes(),
      );
      final mutated = service.reviewIssuesForDetails(
        _detailsWithAllIssueTypes(mutateEvidence: true),
      );
      final baselineIds = baseline.map((issue) => issue.id).toList()..sort();
      final mutatedIds = mutated.map((issue) => issue.id).toList()..sort();

      expect(mutatedIds, baselineIds);
      expect(
        mutated.map((issue) => issue.candidateSummary).toSet(),
        isNot(equals(baseline.map((issue) => issue.candidateSummary).toSet())),
      );
    },
  );

  test('duplicate logical candidates collapse to deterministic evidence', () {
    final service = FoodQualityService();
    final forward = service.reviewIssuesForDetails(
      _detailsWithDuplicateCandidates(reverse: false),
    );
    final reversed = service.reviewIssuesForDetails(
      _detailsWithDuplicateCandidates(reverse: true),
    );

    expect(forward, hasLength(1));
    expect(reversed, hasLength(1));
    expect(forward.single.id, reversed.single.id);
    expect(forward.single.reason, 'Alpha evidence');
    expect(reversed.single.reason, 'Alpha evidence');
    expect(MergeReviewIssueIdentity.tryDecode(forward.single.id), isNotNull);
  });
}

FoodDetails _detailsWithAllIssueTypes({bool mutateEvidence = false}) {
  final createdAt = DateTime.utc(2026, 8, mutateEvidence ? 31 : 30);
  final sources = [
    _source(
      id: 'source:一|reuse',
      action: 'reuse',
      confidence: 0.5,
      candidateId: 'canonical:目标|一',
      createdAt: createdAt,
      mutateEvidence: mutateEvidence,
    ),
    _source(
      id: 'source:二|create',
      action: 'create',
      confidence: 0.9,
      candidateId: 'canonical:目标|二',
      createdAt: createdAt,
      mutateEvidence: mutateEvidence,
    ),
  ];
  final observationAmounts = mutateEvidence
      ? const [40.0, 10.0]
      : const [1.0, 3.0];
  final observationSourceIds = mutateEvidence
      ? const ['source:二|create', 'source:一|reuse']
      : const ['source:一|reuse', 'source:二|create'];
  return FoodDetails(
    id: 'canonical:鲑鱼|主',
    displayName: 'Salmon',
    category: 'Seafood',
    countryHint: 'Canada',
    description: 'Identity fixture',
    servingBasis: 'Per 100 g',
    lastAggregatedAt: createdAt,
    aliases: const [],
    aggregatedNutrients: const [],
    sourceRecords: mutateEvidence ? sources.reversed.toList() : sources,
    nutrientObservations: [
      for (final label in const ['Fat:α|β', 'Protein:α|β']) ...[
        for (var index = 0; index < observationSourceIds.length; index++)
          NutrientObservationView(
            sourceRecordId: observationSourceIds[index],
            label: label,
            canonicalLabel: label,
            amount: observationAmounts[index],
            unit: mutateEvidence ? 'mg' : 'g',
            originalUnit: mutateEvidence ? 'milligrams' : 'g',
          ),
      ],
    ],
  );
}

SourceRecordView _source({
  required String id,
  required String action,
  required double confidence,
  required String candidateId,
  required DateTime createdAt,
  bool mutateEvidence = false,
}) {
  return SourceRecordView(
    id: id,
    importerId: 'fixture',
    sourceName: mutateEvidence ? 'Renamed $id' : id,
    sourceRecordId: id,
    country: 'Testland',
    recordTitle: id,
    recordDescription: 'Identity fixture',
    fetchedAt: createdAt,
    sourceUpdatedAt: createdAt,
    mergeAudit: MergeAuditView(
      sourceRecordId: id,
      action: action,
      confidence: confidence,
      matchedBy: 'fixture',
      reason: mutateEvidence ? 'Updated audit explanation' : 'Identity fixture',
      itemAliasKey: 'salmon',
      itemCategoryKey: 'seafood',
      itemServingKey: 'per 100 g',
      candidateEvaluations: [
        MergeCandidateEvaluationView(
          candidateCanonicalFoodId: candidateId,
          aliasMatched: true,
          categoryMatched: false,
          servingMatched: true,
          nutrientSimilarity: 0.5,
          accepted: mutateEvidence,
          reason: mutateEvidence
              ? 'Updated category evidence'
              : 'Category conflict',
        ),
      ],
      createdAt: createdAt,
    ),
  );
}

FoodDetails _detailsWithDuplicateCandidates({required bool reverse}) {
  final createdAt = DateTime.utc(2026, 8, 30);
  final candidates = [
    _candidate(reason: 'Zulu evidence'),
    _candidate(reason: 'Alpha evidence'),
  ];
  return FoodDetails(
    id: 'canonical:duplicate-fixture',
    displayName: 'Duplicate candidate fixture',
    category: 'Test',
    countryHint: 'Testland',
    description: 'Duplicate candidate fixture',
    servingBasis: 'Per 100 g',
    lastAggregatedAt: createdAt,
    aliases: const [],
    sourceRecords: [
      SourceRecordView(
        id: 'source:duplicate-fixture',
        importerId: 'fixture',
        sourceName: 'Fixture',
        sourceRecordId: 'source:duplicate-fixture',
        country: 'Testland',
        recordTitle: 'Duplicate candidate fixture',
        recordDescription: 'Duplicate candidate fixture',
        fetchedAt: createdAt,
        sourceUpdatedAt: createdAt,
        mergeAudit: MergeAuditView(
          sourceRecordId: 'source:duplicate-fixture',
          action: 'reuse',
          confidence: 0.9,
          matchedBy: 'fixture',
          reason: 'Duplicate candidate fixture',
          itemAliasKey: 'duplicate',
          itemCategoryKey: 'test',
          itemServingKey: 'per 100 g',
          candidateEvaluations: reverse
              ? candidates.reversed.toList()
              : candidates,
          createdAt: createdAt,
        ),
      ),
    ],
    aggregatedNutrients: const [],
    nutrientObservations: const [],
  );
}

MergeCandidateEvaluationView _candidate({required String reason}) {
  return MergeCandidateEvaluationView(
    candidateCanonicalFoodId: 'canonical:同一|candidate',
    aliasMatched: true,
    categoryMatched: false,
    servingMatched: true,
    nutrientSimilarity: 0.5,
    accepted: false,
    reason: reason,
  );
}
