import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewFilter', () {
    test('matches severity and issue type with AND semantics', () {
      const filter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
        type: MergeReviewIssueType.categoryConflictCandidate,
      );

      expect(
        filter.matches(
          _issue(
            severity: MergeReviewSeverity.warning,
            type: MergeReviewIssueType.categoryConflictCandidate,
          ),
        ),
        isTrue,
      );
      expect(
        filter.matches(
          _issue(
            severity: MergeReviewSeverity.high,
            type: MergeReviewIssueType.categoryConflictCandidate,
          ),
        ),
        isFalse,
      );
      expect(
        filter.matches(
          _issue(
            severity: MergeReviewSeverity.warning,
            type: MergeReviewIssueType.lowConfidenceReuse,
          ),
        ),
        isFalse,
      );
    });

    test('round-trips exact enum names in schema version 1', () {
      const filter = MergeReviewFilter(
        severity: MergeReviewSeverity.high,
        type: MergeReviewIssueType.multiSourceNutrientVariance,
      );

      expect(filter.toJson(), {
        'schemaVersion': 1,
        'severity': 'high',
        'type': 'multiSourceNutrientVariance',
      });
      expect(MergeReviewFilter.decode(filter.encode()), filter);
      expect(
        MergeReviewFilter.decode(MergeReviewFilter.all.encode()),
        MergeReviewFilter.all,
      );
    });

    test('strict JSON parser distinguishes valid All from invalid data', () {
      expect(
        MergeReviewFilter.tryFromJson(const {'schemaVersion': 1}),
        MergeReviewFilter.all,
      );
      expect(
        MergeReviewFilter.tryFromJson(const {
          'schemaVersion': 1,
          'severity': 'warning',
          'type': 'lowConfidenceReuse',
        }),
        const MergeReviewFilter(
          severity: MergeReviewSeverity.warning,
          type: MergeReviewIssueType.lowConfidenceReuse,
        ),
      );

      final invalidValues = <Object?>[
        null,
        const [],
        const {'schemaVersion': 1.0},
        const {'schemaVersion': 2},
        const {'schemaVersion': 1, 'futureField': true},
        const {'schemaVersion': 1, 'severity': 'futureSeverity'},
        const {'schemaVersion': 1, 'type': 42},
      ];
      for (final value in invalidValues) {
        expect(
          MergeReviewFilter.tryFromJson(value),
          isNull,
          reason: 'value: $value',
        );
      }
    });

    test('invalid or unsupported payloads fail open to All', () {
      final invalidPayloads = <String?>[
        null,
        '',
        '{',
        '[]',
        '{"schemaVersion":2,"severity":"warning"}',
        '{"schemaVersion":1,"severity":"critical",'
            '"type":"categoryConflictCandidate"}',
        '{"schemaVersion":1,"severity":"warning","type":"futureType"}',
        '{"schemaVersion":1,"severity":42}',
      ];

      for (final payload in invalidPayloads) {
        expect(
          MergeReviewFilter.decode(payload),
          MergeReviewFilter.all,
          reason: 'payload: $payload',
        );
      }
    });
  });
}

MergeReviewIssue _issue({
  required MergeReviewSeverity severity,
  required MergeReviewIssueType type,
}) {
  return MergeReviewIssue(
    id: '${severity.name}-${type.name}',
    canonicalFoodId: 'food-1',
    sourceRecordId: 'source-1',
    type: type,
    severity: severity,
    reason: 'test',
    candidateSummary: 'test',
    createdAt: DateTime(2026),
  );
}
