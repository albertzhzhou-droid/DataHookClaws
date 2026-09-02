import 'dart:convert';

import 'merge_review_filter.dart';

class MergeReviewSavedView {
  factory MergeReviewSavedView({
    required String id,
    required String name,
    required MergeReviewFilter filter,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    final normalizedCreatedAt = createdAt.toUtc();
    final normalizedUpdatedAt = updatedAt.toUtc();
    if (normalizedCreatedAt.isAfter(normalizedUpdatedAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'must not be before createdAt',
      );
    }
    return MergeReviewSavedView._(
      id: normalizedId,
      name: normalizeName(name),
      filter: filter,
      createdAt: normalizedCreatedAt,
      updatedAt: normalizedUpdatedAt,
    );
  }

  const MergeReviewSavedView._({
    required this.id,
    required this.name,
    required this.filter,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxNameLength = 80;
  static final RegExp _whitespace = RegExp(r'\s+');
  static const Set<String> _jsonKeys = {
    'id',
    'name',
    'filter',
    'createdAt',
    'updatedAt',
  };

  final String id;
  final String name;
  final MergeReviewFilter filter;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get normalizedName => name.toLowerCase();

  static String normalizeName(String value) {
    final normalized = value.trim().replaceAll(_whitespace, ' ');
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'name', 'must not be empty');
    }
    if (normalized.length > maxNameLength) {
      throw ArgumentError.value(
        value,
        'name',
        'must be at most $maxNameLength characters after normalization',
      );
    }
    return normalized;
  }

  static MergeReviewSavedView? tryFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    if (value.length != _jsonKeys.length ||
        !value.keys.every((key) => key is String && _jsonKeys.contains(key))) {
      return null;
    }

    final rawId = value['id'];
    final rawName = value['name'];
    final rawCreatedAt = value['createdAt'];
    final rawUpdatedAt = value['updatedAt'];
    final filter = MergeReviewFilter.tryFromJson(value['filter']);
    if (rawId is! String ||
        rawName is! String ||
        rawCreatedAt is! String ||
        rawUpdatedAt is! String ||
        filter == null) {
      return null;
    }

    final createdAt = DateTime.tryParse(rawCreatedAt);
    final updatedAt = DateTime.tryParse(rawUpdatedAt);
    if (createdAt == null || updatedAt == null) {
      return null;
    }

    try {
      return MergeReviewSavedView(
        id: rawId,
        name: rawName,
        filter: filter,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } on ArgumentError {
      return null;
    }
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'name': name,
      'filter': filter.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is MergeReviewSavedView &&
        other.id == id &&
        other.name == name &&
        other.filter == filter &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, name, filter, createdAt, updatedAt);
}

class MergeReviewSavedViewCodec {
  const MergeReviewSavedViewCodec._();

  static const int schemaVersion = 1;
  static const String emptyPayload = '{"schemaVersion":1,"views":[]}';
  static const Set<String> _rootKeys = {'schemaVersion', 'views'};

  static String encode(Iterable<MergeReviewSavedView> views) {
    final encodedViews = views
        .map((view) => view.toJson())
        .toList(growable: false);
    if (encodedViews.isEmpty) {
      return emptyPayload;
    }
    return jsonEncode({'schemaVersion': schemaVersion, 'views': encodedViews});
  }

  static List<MergeReviewSavedView> decode(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return const [];
      }
      if (decoded.length != _rootKeys.length ||
          !decoded.keys.every(
            (key) => key is String && _rootKeys.contains(key),
          )) {
        return const [];
      }
      final rawSchemaVersion = decoded['schemaVersion'];
      final rawViews = decoded['views'];
      if (rawSchemaVersion is! int ||
          rawSchemaVersion != schemaVersion ||
          rawViews is! List) {
        return const [];
      }

      final views = <MergeReviewSavedView>[];
      for (final rawView in rawViews) {
        final view = MergeReviewSavedView.tryFromJson(rawView);
        if (view != null) {
          views.add(view);
        }
      }
      return List<MergeReviewSavedView>.unmodifiable(views);
    } catch (_) {
      return const [];
    }
  }
}
