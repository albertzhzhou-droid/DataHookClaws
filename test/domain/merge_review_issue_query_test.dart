import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewIssuePage', () {
    test('filters the full backlog before applying the page limit', () {
      final recent = [
        for (var index = 0; index < 101; index++)
          _issue(
            id: 'recent-$index',
            severity: MergeReviewSeverity.high,
            type: MergeReviewIssueType.categoryConflictCandidate,
            createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
          ),
      ];
      final target = _issue(
        id: 'old-warning-target',
        severity: MergeReviewSeverity.warning,
        type: MergeReviewIssueType.lowConfidenceReuse,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final issues = [...recent, target];

      final allPage = MergeReviewIssuePage.fromIssues(
        issues: issues,
        query: MergeReviewIssueQuery(limit: 100),
      );
      final filteredPage = MergeReviewIssuePage.fromIssues(
        issues: issues,
        query: MergeReviewIssueQuery(
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
            type: MergeReviewIssueType.lowConfidenceReuse,
          ),
          limit: 100,
        ),
      );

      expect(allPage.items, hasLength(100));
      expect(allPage.items, isNot(contains(target)));
      expect(allPage.totalCount, 102);
      expect(allPage.matchingCount, 102);
      expect(allPage.hasNext, isTrue);
      expect(filteredPage.items, [target]);
      expect(filteredPage.totalCount, 102);
      expect(filteredPage.matchingCount, 1);
      expect(filteredPage.hasNext, isFalse);
    });

    test('uses deterministic id ordering for equal timestamps', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final issues = [
        _issue(id: 'c', createdAt: createdAt),
        _issue(id: 'a', createdAt: createdAt),
        _issue(id: 'b', createdAt: createdAt),
      ];

      final first = MergeReviewIssuePage.fromIssues(
        issues: issues,
        query: MergeReviewIssueQuery(limit: 1),
      );
      final second = MergeReviewIssuePage.fromIssues(
        issues: issues,
        query: MergeReviewIssueQuery(offset: 1, limit: 1),
      );
      final beyond = MergeReviewIssuePage.fromIssues(
        issues: issues,
        query: MergeReviewIssueQuery(offset: 3, limit: 1),
      );

      expect(first.items.single.id, 'a');
      expect(first.hasPrevious, isFalse);
      expect(first.hasMore, isTrue);
      expect(second.items.single.id, 'b');
      expect(second.hasPrevious, isTrue);
      expect(second.previousOffset, 0);
      expect(second.nextOffset, 2);
      expect(beyond.items, isEmpty);
      expect(beyond.totalCount, 3);
      expect(beyond.matchingCount, 3);
    });

    test('requires a non-negative offset and positive limit', () {
      expect(() => MergeReviewIssueQuery(offset: -1), throwsRangeError);
      expect(() => MergeReviewIssueQuery(limit: 0), throwsRangeError);
    });

    test('legacy repository limit zero remains an empty result', () async {
      final repository = MemoryFoodRepository();

      expect(await repository.getMergeReviewIssues(limit: 0), isEmpty);
    });
  });
}

MergeReviewIssue _issue({
  required String id,
  required DateTime createdAt,
  MergeReviewSeverity severity = MergeReviewSeverity.info,
  MergeReviewIssueType type = MergeReviewIssueType.createdWithCandidates,
}) {
  return MergeReviewIssue(
    id: id,
    canonicalFoodId: 'food-$id',
    sourceRecordId: 'source-$id',
    type: type,
    severity: severity,
    reason: 'reason-$id',
    candidateSummary: 'candidate-$id',
    createdAt: createdAt,
  );
}
