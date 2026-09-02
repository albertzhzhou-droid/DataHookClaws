import 'dart:async';
import 'dart:convert';

import '../data/food_repository.dart';
import '../models/merge_review_filter.dart';
import '../models/merge_review_saved_view.dart';

class MergeReviewSavedViewStore {
  MergeReviewSavedViewStore(
    this._repository, {
    int maxItems = 12,
    int maxValueLength = 1048576,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       maxItems = _validateMaxItems(maxItems),
       maxValueLength = _validateMaxValueLength(maxValueLength);

  static const String metaKey = 'merge_review_saved_views_v1';
  static final Expando<_MergeReviewSavedViewQueue> _queues =
      Expando<_MergeReviewSavedViewQueue>('merge-review-saved-view-queues');

  final FoodRepository _repository;
  final int maxItems;
  final int maxValueLength;
  final DateTime Function() _clock;

  Future<List<MergeReviewSavedView>> load() {
    return _runSerialized(_loadUnlocked);
  }

  Future<List<MergeReviewSavedView>> save({
    required String name,
    required MergeReviewFilter filter,
  }) {
    return _runSerialized(() async {
      final normalizedName = MergeReviewSavedView.normalizeName(name);
      final existing = await _loadUnlocked();
      final existingIndex = existing.indexWhere(
        (view) => view.normalizedName == normalizedName.toLowerCase(),
      );
      final now = _clock().toUtc();

      late final MergeReviewSavedView savedView;
      final next = List<MergeReviewSavedView>.from(existing);
      if (existingIndex >= 0) {
        final previous = existing[existingIndex];
        final updatedAt = now.isBefore(previous.updatedAt)
            ? previous.updatedAt
            : now;
        savedView = MergeReviewSavedView(
          id: previous.id,
          name: normalizedName,
          filter: filter,
          createdAt: previous.createdAt,
          updatedAt: updatedAt,
        );
        next[existingIndex] = savedView;
      } else {
        if (existing.length >= maxItems) {
          throw StateError(
            'Merge review saved view limit of $maxItems reached.',
          );
        }
        savedView = MergeReviewSavedView(
          id: _nextId(existing, now),
          name: normalizedName,
          filter: filter,
          createdAt: now,
          updatedAt: now,
        );
        next.add(savedView);
      }

      return _persistUnlocked(_canonicalize(next));
    });
  }

  Future<List<MergeReviewSavedView>> remove(String id) {
    return _runSerialized(() async {
      final normalizedId = id.trim();
      final existing = await _loadUnlocked();
      if (normalizedId.isEmpty ||
          !existing.any((view) => view.id == normalizedId)) {
        return existing;
      }
      final next = existing
          .where((view) => view.id != normalizedId)
          .toList(growable: false);
      return _persistUnlocked(next);
    });
  }

  Future<void> clear() {
    return _runSerialized(() async {
      await _repository.setAppMeta(
        metaKey,
        MergeReviewSavedViewCodec.emptyPayload,
      );
    });
  }

  Future<List<MergeReviewSavedView>> _loadUnlocked() async {
    final rawValue = await _repository.getAppMeta(metaKey);
    if (rawValue == null || _payloadLength(rawValue) > maxValueLength) {
      return const [];
    }
    return _canonicalize(MergeReviewSavedViewCodec.decode(rawValue));
  }

  Future<List<MergeReviewSavedView>> _persistUnlocked(
    List<MergeReviewSavedView> views,
  ) async {
    final canonical = _canonicalize(views);
    final payload = MergeReviewSavedViewCodec.encode(canonical);
    if (_payloadLength(payload) > maxValueLength) {
      throw StateError(
        'Merge review saved view payload exceeds $maxValueLength bytes.',
      );
    }
    await _repository.setAppMeta(metaKey, payload);
    return canonical;
  }

  List<MergeReviewSavedView> _canonicalize(
    Iterable<MergeReviewSavedView> source,
  ) {
    final sorted = List<MergeReviewSavedView>.from(source)..sort(_compareViews);
    final seenIds = <String>{};
    final seenNames = <String>{};
    final canonical = <MergeReviewSavedView>[];
    for (final view in sorted) {
      if (!seenIds.add(view.id) || !seenNames.add(view.normalizedName)) {
        continue;
      }
      canonical.add(view);
      if (canonical.length >= maxItems) {
        break;
      }
    }
    return List<MergeReviewSavedView>.unmodifiable(canonical);
  }

  int _compareViews(MergeReviewSavedView left, MergeReviewSavedView right) {
    final updatedAt = right.updatedAt.compareTo(left.updatedAt);
    if (updatedAt != 0) {
      return updatedAt;
    }
    final name = left.normalizedName.compareTo(right.normalizedName);
    if (name != 0) {
      return name;
    }
    return left.id.compareTo(right.id);
  }

  String _nextId(List<MergeReviewSavedView> existing, DateTime now) {
    final usedIds = existing.map((view) => view.id).toSet();
    final base = now.microsecondsSinceEpoch.toString();
    var candidate = base;
    var suffix = 2;
    while (usedIds.contains(candidate)) {
      candidate = '$base-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  int _payloadLength(String payload) => utf8.encode(payload).length;

  static int _validateMaxItems(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'maxItems', 'must be greater than zero');
    }
    return value;
  }

  static int _validateMaxValueLength(int value) {
    final minimum = utf8.encode(MergeReviewSavedViewCodec.emptyPayload).length;
    if (value < minimum) {
      throw ArgumentError.value(
        value,
        'maxValueLength',
        'must be at least $minimum UTF-8 bytes',
      );
    }
    return value;
  }

  Future<T> _runSerialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    final queue = _queueForRepository();
    queue.tail = queue.tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  _MergeReviewSavedViewQueue _queueForRepository() {
    final existing = _queues[_repository];
    if (existing != null) {
      return existing;
    }
    final created = _MergeReviewSavedViewQueue();
    _queues[_repository] = created;
    return created;
  }
}

class _MergeReviewSavedViewQueue {
  Future<void> tail = Future<void>.value();
}
