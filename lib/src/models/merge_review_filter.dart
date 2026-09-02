import 'dart:convert';

import 'merge_review_issue.dart';

class MergeReviewFilter {
  const MergeReviewFilter({this.severity, this.type});

  static const int schemaVersion = 1;
  static const MergeReviewFilter all = MergeReviewFilter();
  static const Set<String> _jsonKeys = {'schemaVersion', 'severity', 'type'};

  final MergeReviewSeverity? severity;
  final MergeReviewIssueType? type;

  bool get isActive => severity != null || type != null;

  bool matches(MergeReviewIssue issue) {
    return (severity == null || issue.severity == severity) &&
        (type == null || issue.type == type);
  }

  MergeReviewFilter withSeverity(MergeReviewSeverity? nextSeverity) {
    return MergeReviewFilter(severity: nextSeverity, type: type);
  }

  MergeReviewFilter withType(MergeReviewIssueType? nextType) {
    return MergeReviewFilter(severity: severity, type: nextType);
  }

  Map<String, Object> toJson() {
    return {
      'schemaVersion': schemaVersion,
      if (severity != null) 'severity': severity!.name,
      if (type != null) 'type': type!.name,
    };
  }

  String encode() => jsonEncode(toJson());

  static MergeReviewFilter decode(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return all;
    }

    try {
      return tryFromJson(jsonDecode(rawValue)) ?? all;
    } catch (_) {
      return all;
    }
  }

  static MergeReviewFilter? tryFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    if (!value.keys.every((key) => key is String && _jsonKeys.contains(key))) {
      return null;
    }
    final rawSchemaVersion = value['schemaVersion'];
    if (rawSchemaVersion is! int || rawSchemaVersion != schemaVersion) {
      return null;
    }

    final rawSeverity = value['severity'];
    final rawType = value['type'];
    final severity = _severityFromName(rawSeverity);
    final type = _typeFromName(rawType);
    if ((rawSeverity != null && severity == null) ||
        (rawType != null && type == null)) {
      return null;
    }
    return MergeReviewFilter(severity: severity, type: type);
  }

  static MergeReviewSeverity? _severityFromName(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      return null;
    }
    for (final severity in MergeReviewSeverity.values) {
      if (severity.name == value) {
        return severity;
      }
    }
    return null;
  }

  static MergeReviewIssueType? _typeFromName(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      return null;
    }
    for (final type in MergeReviewIssueType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is MergeReviewFilter &&
        other.severity == severity &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(severity, type);
}
