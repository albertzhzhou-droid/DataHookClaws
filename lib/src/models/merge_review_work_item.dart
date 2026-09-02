import 'dart:convert';

import 'merge_review_issue.dart';
import 'merge_review_issue_identity.dart';

enum MergeReviewWorkItemStatus { queued, deferred }

class MergeReviewWorkItem {
  factory MergeReviewWorkItem({
    required String issueId,
    required String canonicalFoodId,
    required String identitySourceRecordId,
    required String targetSourceRecordId,
    required MergeReviewIssueType type,
    required String subjectKey,
    required MergeReviewWorkItemStatus status,
    required String? suggestedCanonicalFoodId,
    required String reason,
    required String candidateSummary,
    required DateTime issueCreatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final identity = MergeReviewIssueIdentity.tryDecode(issueId);
    if (identity == null) {
      throw ArgumentError.value(
        issueId,
        'issueId',
        'must be a valid merge review issue identity',
      );
    }
    if (identity.canonicalFoodId != canonicalFoodId ||
        identity.sourceRecordId != identitySourceRecordId ||
        identity.type != type ||
        identity.subjectKey != subjectKey) {
      throw ArgumentError.value(
        issueId,
        'issueId',
        'identity fields must exactly match the work item snapshots',
      );
    }
    final isNutrientVariance =
        type == MergeReviewIssueType.multiSourceNutrientVariance;
    if (isNutrientVariance) {
      if (identitySourceRecordId.isNotEmpty) {
        throw ArgumentError.value(
          identitySourceRecordId,
          'identitySourceRecordId',
          'must be empty for canonical-level nutrient variance identities',
        );
      }
    } else if (identitySourceRecordId.isEmpty ||
        targetSourceRecordId != identitySourceRecordId) {
      throw ArgumentError.value(
        targetSourceRecordId,
        'targetSourceRecordId',
        'must match the non-empty identity source for source-scoped issues',
      );
    }

    final normalizedSuggestedCanonicalFoodId = suggestedCanonicalFoodId?.trim();
    if (normalizedSuggestedCanonicalFoodId != null &&
        normalizedSuggestedCanonicalFoodId.isEmpty) {
      throw ArgumentError.value(
        suggestedCanonicalFoodId,
        'suggestedCanonicalFoodId',
        'must be null or non-empty',
      );
    }

    final normalizedIssueCreatedAt = issueCreatedAt.toUtc();
    final normalizedCreatedAt = createdAt.toUtc();
    final normalizedUpdatedAt = updatedAt.toUtc();
    if (normalizedCreatedAt.isAfter(normalizedUpdatedAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'must not be before createdAt',
      );
    }

    return MergeReviewWorkItem._(
      issueId: issueId,
      canonicalFoodId: canonicalFoodId,
      identitySourceRecordId: identitySourceRecordId,
      targetSourceRecordId: targetSourceRecordId,
      type: type,
      subjectKey: subjectKey,
      status: status,
      suggestedCanonicalFoodId: normalizedSuggestedCanonicalFoodId,
      reason: reason,
      candidateSummary: candidateSummary,
      issueCreatedAt: normalizedIssueCreatedAt,
      createdAt: normalizedCreatedAt,
      updatedAt: normalizedUpdatedAt,
    );
  }

  factory MergeReviewWorkItem.fromIssue({
    required MergeReviewIssue issue,
    required DateTime createdAt,
    DateTime? updatedAt,
    MergeReviewWorkItemStatus status = MergeReviewWorkItemStatus.queued,
  }) {
    final identity = MergeReviewIssueIdentity.tryDecode(issue.id);
    if (identity == null) {
      throw ArgumentError.value(
        issue.id,
        'issue.id',
        'must be a valid merge review issue identity',
      );
    }
    if (identity.canonicalFoodId != issue.canonicalFoodId ||
        identity.type != issue.type) {
      throw ArgumentError.value(
        issue.id,
        'issue.id',
        'identity canonical food and type must match the issue snapshot',
      );
    }
    final isNutrientVariance =
        identity.type == MergeReviewIssueType.multiSourceNutrientVariance;
    if ((isNutrientVariance && identity.sourceRecordId.isNotEmpty) ||
        (!isNutrientVariance &&
            (identity.sourceRecordId.isEmpty ||
                identity.sourceRecordId != issue.sourceRecordId))) {
      throw ArgumentError.value(
        issue.id,
        'issue.id',
        'identity source does not match the issue type and target source',
      );
    }
    return MergeReviewWorkItem(
      issueId: issue.id,
      canonicalFoodId: identity.canonicalFoodId,
      identitySourceRecordId: identity.sourceRecordId,
      targetSourceRecordId: issue.sourceRecordId,
      type: identity.type,
      subjectKey: identity.subjectKey,
      status: status,
      suggestedCanonicalFoodId: issue.suggestedCanonicalFoodId,
      reason: issue.reason,
      candidateSummary: issue.candidateSummary,
      issueCreatedAt: issue.createdAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  const MergeReviewWorkItem._({
    required this.issueId,
    required this.canonicalFoodId,
    required this.identitySourceRecordId,
    required this.targetSourceRecordId,
    required this.type,
    required this.subjectKey,
    required this.status,
    required this.suggestedCanonicalFoodId,
    required this.reason,
    required this.candidateSummary,
    required this.issueCreatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static const Set<String> _jsonKeys = {
    'issueId',
    'canonicalFoodId',
    'identitySourceRecordId',
    'targetSourceRecordId',
    'type',
    'subjectKey',
    'status',
    'suggestedCanonicalFoodId',
    'reason',
    'candidateSummary',
    'issueCreatedAt',
    'createdAt',
    'updatedAt',
  };

  final String issueId;
  final String canonicalFoodId;
  final String identitySourceRecordId;
  final String targetSourceRecordId;
  final MergeReviewIssueType type;
  final String subjectKey;
  final MergeReviewWorkItemStatus status;
  final String? suggestedCanonicalFoodId;
  final String reason;
  final String candidateSummary;
  final DateTime issueCreatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MergeReviewIssueIdentity get identity =>
      MergeReviewIssueIdentity.tryDecode(issueId)!;

  MergeReviewWorkItem copyWith({
    MergeReviewWorkItemStatus? status,
    DateTime? updatedAt,
  }) {
    return MergeReviewWorkItem(
      issueId: issueId,
      canonicalFoodId: canonicalFoodId,
      identitySourceRecordId: identitySourceRecordId,
      targetSourceRecordId: targetSourceRecordId,
      type: type,
      subjectKey: subjectKey,
      status: status ?? this.status,
      suggestedCanonicalFoodId: suggestedCanonicalFoodId,
      reason: reason,
      candidateSummary: candidateSummary,
      issueCreatedAt: issueCreatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static MergeReviewWorkItem? tryFromJson(Object? value) {
    if (value is! Map ||
        value.length != _jsonKeys.length ||
        !value.keys.every(_jsonKeys.contains)) {
      return null;
    }

    final rawIssueId = value['issueId'];
    final rawCanonicalFoodId = value['canonicalFoodId'];
    final rawIdentitySourceRecordId = value['identitySourceRecordId'];
    final rawTargetSourceRecordId = value['targetSourceRecordId'];
    final rawType = value['type'];
    final rawSubjectKey = value['subjectKey'];
    final rawStatus = value['status'];
    final rawSuggestedCanonicalFoodId = value['suggestedCanonicalFoodId'];
    final rawReason = value['reason'];
    final rawCandidateSummary = value['candidateSummary'];
    final rawIssueCreatedAt = value['issueCreatedAt'];
    final rawCreatedAt = value['createdAt'];
    final rawUpdatedAt = value['updatedAt'];
    if (rawIssueId is! String ||
        rawCanonicalFoodId is! String ||
        rawIdentitySourceRecordId is! String ||
        rawTargetSourceRecordId is! String ||
        rawType is! String ||
        rawSubjectKey is! String ||
        rawStatus is! String ||
        (rawSuggestedCanonicalFoodId != null &&
            rawSuggestedCanonicalFoodId is! String) ||
        rawReason is! String ||
        rawCandidateSummary is! String ||
        rawIssueCreatedAt is! String ||
        rawCreatedAt is! String ||
        rawUpdatedAt is! String) {
      return null;
    }

    final type = _typeFromToken(rawType);
    final status = _statusFromToken(rawStatus);
    final issueCreatedAt = DateTime.tryParse(rawIssueCreatedAt);
    final createdAt = DateTime.tryParse(rawCreatedAt);
    final updatedAt = DateTime.tryParse(rawUpdatedAt);
    if (type == null ||
        status == null ||
        issueCreatedAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    try {
      return MergeReviewWorkItem(
        issueId: rawIssueId,
        canonicalFoodId: rawCanonicalFoodId,
        identitySourceRecordId: rawIdentitySourceRecordId,
        targetSourceRecordId: rawTargetSourceRecordId,
        type: type,
        subjectKey: rawSubjectKey,
        status: status,
        suggestedCanonicalFoodId: rawSuggestedCanonicalFoodId as String?,
        reason: rawReason,
        candidateSummary: rawCandidateSummary,
        issueCreatedAt: issueCreatedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } on ArgumentError {
      return null;
    }
  }

  Map<String, Object?> toJson() {
    return {
      'issueId': issueId,
      'canonicalFoodId': canonicalFoodId,
      'identitySourceRecordId': identitySourceRecordId,
      'targetSourceRecordId': targetSourceRecordId,
      'type': _typeToken(type),
      'subjectKey': subjectKey,
      'status': _statusToken(status),
      'suggestedCanonicalFoodId': suggestedCanonicalFoodId,
      'reason': reason,
      'candidateSummary': candidateSummary,
      'issueCreatedAt': issueCreatedAt.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String _typeToken(MergeReviewIssueType type) {
    return switch (type) {
      MergeReviewIssueType.lowConfidenceReuse => 'lowConfidenceReuse',
      MergeReviewIssueType.categoryConflictCandidate =>
        'categoryConflictCandidate',
      MergeReviewIssueType.createdWithCandidates => 'createdWithCandidates',
      MergeReviewIssueType.multiSourceNutrientVariance =>
        'multiSourceNutrientVariance',
    };
  }

  static MergeReviewIssueType? _typeFromToken(String value) {
    return switch (value) {
      'lowConfidenceReuse' => MergeReviewIssueType.lowConfidenceReuse,
      'categoryConflictCandidate' =>
        MergeReviewIssueType.categoryConflictCandidate,
      'createdWithCandidates' => MergeReviewIssueType.createdWithCandidates,
      'multiSourceNutrientVariance' =>
        MergeReviewIssueType.multiSourceNutrientVariance,
      _ => null,
    };
  }

  static String _statusToken(MergeReviewWorkItemStatus status) {
    return switch (status) {
      MergeReviewWorkItemStatus.queued => 'queued',
      MergeReviewWorkItemStatus.deferred => 'deferred',
    };
  }

  static MergeReviewWorkItemStatus? _statusFromToken(String value) {
    return switch (value) {
      'queued' => MergeReviewWorkItemStatus.queued,
      'deferred' => MergeReviewWorkItemStatus.deferred,
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is MergeReviewWorkItem &&
        other.issueId == issueId &&
        other.canonicalFoodId == canonicalFoodId &&
        other.identitySourceRecordId == identitySourceRecordId &&
        other.targetSourceRecordId == targetSourceRecordId &&
        other.type == type &&
        other.subjectKey == subjectKey &&
        other.status == status &&
        other.suggestedCanonicalFoodId == suggestedCanonicalFoodId &&
        other.reason == reason &&
        other.candidateSummary == candidateSummary &&
        other.issueCreatedAt == issueCreatedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    issueId,
    canonicalFoodId,
    identitySourceRecordId,
    targetSourceRecordId,
    type,
    subjectKey,
    status,
    suggestedCanonicalFoodId,
    reason,
    candidateSummary,
    issueCreatedAt,
    createdAt,
    updatedAt,
  );
}

class MergeReviewWorkItemCodec {
  const MergeReviewWorkItemCodec._();

  static const int schemaVersion = 1;
  static const String emptyPayload = '{"schemaVersion":1,"items":[]}';
  static const Set<String> _jsonKeys = {'schemaVersion', 'items'};

  static String encode(Iterable<MergeReviewWorkItem> items) {
    final encodedItems = items
        .map((item) => item.toJson())
        .toList(growable: false);
    if (encodedItems.isEmpty) {
      return emptyPayload;
    }
    return jsonEncode({'schemaVersion': schemaVersion, 'items': encodedItems});
  }

  static List<MergeReviewWorkItem> decode(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map ||
          decoded.length != _jsonKeys.length ||
          !decoded.keys.every(_jsonKeys.contains)) {
        return const [];
      }
      final rawSchemaVersion = decoded['schemaVersion'];
      final rawItems = decoded['items'];
      if (rawSchemaVersion is! int ||
          rawSchemaVersion != schemaVersion ||
          rawItems is! List) {
        return const [];
      }

      final items = <MergeReviewWorkItem>[];
      for (final rawItem in rawItems) {
        final item = MergeReviewWorkItem.tryFromJson(rawItem);
        if (item != null) {
          items.add(item);
        }
      }
      return List<MergeReviewWorkItem>.unmodifiable(items);
    } catch (_) {
      return const [];
    }
  }
}
