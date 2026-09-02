import 'merge_review_filter.dart';
import 'merge_review_issue.dart';

class MergeReviewIssueQuery {
  factory MergeReviewIssueQuery({
    MergeReviewFilter filter = MergeReviewFilter.all,
    int offset = 0,
    int limit = 100,
  }) {
    if (offset < 0) {
      throw RangeError.range(offset, 0, null, 'offset');
    }
    if (limit <= 0) {
      throw RangeError.range(limit, 1, null, 'limit');
    }
    return MergeReviewIssueQuery._(
      filter: filter,
      offset: offset,
      limit: limit,
    );
  }

  const MergeReviewIssueQuery._({
    required this.filter,
    required this.offset,
    required this.limit,
  });

  static const MergeReviewIssueQuery all = MergeReviewIssueQuery._(
    filter: MergeReviewFilter.all,
    offset: 0,
    limit: 100,
  );

  final MergeReviewFilter filter;
  final int offset;
  final int limit;
}

class MergeReviewIssuePage {
  const MergeReviewIssuePage({
    required this.items,
    required this.totalCount,
    required this.matchingCount,
    required this.offset,
    required this.limit,
  }) : assert(totalCount >= 0),
       assert(matchingCount >= 0),
       assert(matchingCount <= totalCount),
       assert(offset >= 0),
       assert(limit > 0);

  static const MergeReviewIssuePage empty = MergeReviewIssuePage(
    items: [],
    totalCount: 0,
    matchingCount: 0,
    offset: 0,
    limit: 100,
  );

  factory MergeReviewIssuePage.fromIssues({
    required Iterable<MergeReviewIssue> issues,
    required MergeReviewIssueQuery query,
  }) {
    final ordered = List<MergeReviewIssue>.from(issues)
      ..sort((left, right) {
        final createdAt = right.createdAt.compareTo(left.createdAt);
        if (createdAt != 0) {
          return createdAt;
        }
        return left.id.compareTo(right.id);
      });
    final matching = ordered
        .where(query.filter.matches)
        .toList(growable: false);
    final pageItems = matching
        .skip(query.offset)
        .take(query.limit)
        .toList(growable: false);
    return MergeReviewIssuePage(
      items: List<MergeReviewIssue>.unmodifiable(pageItems),
      totalCount: ordered.length,
      matchingCount: matching.length,
      offset: query.offset,
      limit: query.limit,
    );
  }

  final List<MergeReviewIssue> items;
  final int totalCount;
  final int matchingCount;
  final int offset;
  final int limit;

  bool get hasPrevious => offset > 0;

  bool get hasNext => offset + items.length < matchingCount;

  bool get hasMore => hasNext;

  int get previousOffset => offset > limit ? offset - limit : 0;

  int get nextOffset => offset + limit;
}
