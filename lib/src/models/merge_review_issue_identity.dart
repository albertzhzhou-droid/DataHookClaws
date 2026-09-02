import 'dart:convert';

import 'merge_review_issue.dart';

class MergeReviewIssueIdentity {
  factory MergeReviewIssueIdentity({
    required String canonicalFoodId,
    required String sourceRecordId,
    required MergeReviewIssueType type,
    required String subjectKey,
  }) {
    final normalizedCanonicalFoodId = canonicalFoodId.trim();
    final normalizedSourceRecordId = sourceRecordId.trim();
    final normalizedSubjectKey = subjectKey.trim();
    if (normalizedCanonicalFoodId.isEmpty) {
      throw ArgumentError.value(
        canonicalFoodId,
        'canonicalFoodId',
        'must not be empty',
      );
    }
    if (normalizedSubjectKey.isEmpty) {
      throw ArgumentError.value(subjectKey, 'subjectKey', 'must not be empty');
    }
    return MergeReviewIssueIdentity._(
      canonicalFoodId: normalizedCanonicalFoodId,
      sourceRecordId: normalizedSourceRecordId,
      type: type,
      subjectKey: normalizedSubjectKey,
    );
  }

  const MergeReviewIssueIdentity._({
    required this.canonicalFoodId,
    required this.sourceRecordId,
    required this.type,
    required this.subjectKey,
  });

  static const int schemaVersion = 1;
  static const String encodedPrefix = 'merge-review-issue:';
  static const Set<String> _jsonKeys = {
    'schemaVersion',
    'canonicalFoodId',
    'sourceRecordId',
    'type',
    'subjectKey',
  };
  static final RegExp _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final String canonicalFoodId;
  final String sourceRecordId;
  final MergeReviewIssueType type;
  final String subjectKey;

  Map<String, Object> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'canonicalFoodId': canonicalFoodId,
      'sourceRecordId': sourceRecordId,
      'type': _typeToken(type),
      'subjectKey': subjectKey,
    };
  }

  String encode() {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(toJson())))
        .replaceAll('=', '');
    return '$encodedPrefix$payload';
  }

  static MergeReviewIssueIdentity? tryDecode(String? encoded) {
    if (encoded == null || !encoded.startsWith(encodedPrefix)) {
      return null;
    }
    final payload = encoded.substring(encodedPrefix.length);
    if (payload.isEmpty || !_base64UrlPattern.hasMatch(payload)) {
      return null;
    }

    try {
      final decodedBytes = base64Url.decode(_withPadding(payload));
      final decodedJson = jsonDecode(utf8.decode(decodedBytes));
      if (decodedJson is! Map ||
          decodedJson.length != _jsonKeys.length ||
          !decodedJson.keys.every(_jsonKeys.contains)) {
        return null;
      }

      final rawSchemaVersion = decodedJson['schemaVersion'];
      final rawCanonicalFoodId = decodedJson['canonicalFoodId'];
      final rawSourceRecordId = decodedJson['sourceRecordId'];
      final rawType = decodedJson['type'];
      final rawSubjectKey = decodedJson['subjectKey'];
      if (rawSchemaVersion is! int ||
          rawSchemaVersion != schemaVersion ||
          rawCanonicalFoodId is! String ||
          rawSourceRecordId is! String ||
          rawType is! String ||
          rawSubjectKey is! String) {
        return null;
      }
      final type = _typeFromToken(rawType);
      if (type == null) {
        return null;
      }

      final identity = MergeReviewIssueIdentity(
        canonicalFoodId: rawCanonicalFoodId,
        sourceRecordId: rawSourceRecordId,
        type: type,
        subjectKey: rawSubjectKey,
      );
      if (identity.encode() != encoded) {
        return null;
      }
      return identity;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static String _withPadding(String payload) {
    final remainder = payload.length % 4;
    if (remainder == 0) {
      return payload;
    }
    return payload.padRight(payload.length + (4 - remainder), '=');
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

  @override
  bool operator ==(Object other) {
    return other is MergeReviewIssueIdentity &&
        other.canonicalFoodId == canonicalFoodId &&
        other.sourceRecordId == sourceRecordId &&
        other.type == type &&
        other.subjectKey == subjectKey;
  }

  @override
  int get hashCode =>
      Object.hash(canonicalFoodId, sourceRecordId, type, subjectKey);
}
