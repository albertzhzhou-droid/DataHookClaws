enum MergeReviewIssueType {
  lowConfidenceReuse,
  categoryConflictCandidate,
  createdWithCandidates,
  multiSourceNutrientVariance,
}

enum MergeReviewSeverity { info, warning, high }

class MergeReviewIssue {
  const MergeReviewIssue({
    required this.id,
    required this.canonicalFoodId,
    required this.sourceRecordId,
    required this.type,
    required this.severity,
    required this.reason,
    required this.candidateSummary,
    required this.createdAt,
    this.suggestedCanonicalFoodId,
  });

  final String id;
  final String canonicalFoodId;
  final String sourceRecordId;
  final MergeReviewIssueType type;
  final MergeReviewSeverity severity;
  final String reason;
  final String candidateSummary;
  final DateTime createdAt;
  final String? suggestedCanonicalFoodId;
}
