import 'dart:async';
import 'dart:convert';

import '../data/food_repository.dart';
import '../models/merge_review_issue.dart';
import '../models/merge_review_issue_identity.dart';
import '../models/merge_review_work_item.dart';

class MergeReviewWorklistUpsert {
  const MergeReviewWorklistUpsert({required this.issue, required this.status});

  final MergeReviewIssue issue;
  final MergeReviewWorkItemStatus status;
}

class MergeReviewWorklistStore {
  MergeReviewWorklistStore(
    FoodRepository repository, {
    int maxItems = 500,
    int maxValueLength = 1048576,
    DateTime Function()? clock,
  }) : _repository = repository,
       maxItems = _validateMaxItems(maxItems),
       maxValueLength = _validateMaxValueLength(maxValueLength),
       _clock = clock ?? DateTime.now;

  static const String metaKey = 'merge_review_worklist_v1';
  static final Expando<_MergeReviewWorklistQueue> _queues =
      Expando<_MergeReviewWorklistQueue>('merge-review-worklist-queues');
  static final DateTime _preflightTimestamp =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final FoodRepository _repository;
  final int maxItems;
  final int maxValueLength;
  final DateTime Function() _clock;

  Future<List<MergeReviewWorkItem>> load() {
    return _runSerialized(() async => (await _loadStateUnlocked()).items);
  }

  Future<List<MergeReviewWorkItem>> upsertAll(
    Iterable<MergeReviewWorklistUpsert> mutations,
  ) {
    late final List<MergeReviewWorklistUpsert> validated;
    try {
      validated = List<MergeReviewWorklistUpsert>.unmodifiable(mutations);
      for (final mutation in validated) {
        MergeReviewWorkItem.fromIssue(
          issue: mutation.issue,
          createdAt: _preflightTimestamp,
          status: mutation.status,
        );
      }
    } catch (error, stackTrace) {
      return Future<List<MergeReviewWorkItem>>.error(error, stackTrace);
    }

    return _runSerialized(() async {
      final loadState = await _loadStateUnlocked();
      if (validated.isEmpty) {
        return loadState.items;
      }
      _ensureWritable(loadState);
      final existing = loadState.items;
      final now = _clock().toUtc();
      final byIssueId = <String, MergeReviewWorkItem>{
        for (final item in existing) item.issueId: item,
      };
      for (final mutation in validated) {
        final previous = byIssueId[mutation.issue.id];
        final updatedAt = previous == null || !now.isBefore(previous.updatedAt)
            ? now
            : previous.updatedAt;
        byIssueId[mutation.issue.id] = MergeReviewWorkItem.fromIssue(
          issue: mutation.issue,
          status: mutation.status,
          createdAt: previous?.createdAt ?? now,
          updatedAt: updatedAt,
        );
      }
      if (byIssueId.length > maxItems) {
        throw StateError('Merge review worklist limit of $maxItems reached.');
      }
      return _persistUnlocked(byIssueId.values);
    });
  }

  Future<List<MergeReviewWorkItem>> remove(String issueId) {
    return removeAll([issueId]);
  }

  Future<List<MergeReviewWorkItem>> removeAll(Iterable<String> issueIds) {
    final validatedIds = <String>{};
    try {
      for (final issueId in issueIds) {
        if (MergeReviewIssueIdentity.tryDecode(issueId) == null) {
          throw ArgumentError.value(
            issueId,
            'issueIds',
            'must contain only structured merge review issue identities',
          );
        }
        validatedIds.add(issueId);
      }
    } catch (error, stackTrace) {
      return Future<List<MergeReviewWorkItem>>.error(error, stackTrace);
    }

    return _runSerialized(() async {
      final loadState = await _loadStateUnlocked();
      if (validatedIds.isEmpty) {
        return loadState.items;
      }
      _ensureWritable(loadState);
      final existing = loadState.items;
      if (!existing.any((item) => validatedIds.contains(item.issueId))) {
        return existing;
      }
      final remaining = existing
          .where((item) => !validatedIds.contains(item.issueId))
          .toList(growable: false);
      return _persistUnlocked(remaining);
    });
  }

  Future<void> clear() {
    return _runSerialized(() async {
      await _repository.setAppMeta(
        metaKey,
        MergeReviewWorkItemCodec.emptyPayload,
      );
    });
  }

  Future<_MergeReviewWorklistLoadState> _loadStateUnlocked() async {
    final rawValue = await _repository.getAppMeta(metaKey);
    if (rawValue == null) {
      return const _MergeReviewWorklistLoadState(items: [], writable: true);
    }
    if (_payloadLength(rawValue) > maxValueLength) {
      return const _MergeReviewWorklistLoadState(items: [], writable: false);
    }
    if (rawValue.trim().isEmpty) {
      return const _MergeReviewWorklistLoadState(items: [], writable: false);
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map ||
          decoded.length != 2 ||
          decoded['schemaVersion'] is! int ||
          decoded['schemaVersion'] != MergeReviewWorkItemCodec.schemaVersion ||
          decoded['items'] is! List) {
        return const _MergeReviewWorklistLoadState(items: [], writable: false);
      }
      final rawItems = decoded['items'] as List;
      final validItems = <MergeReviewWorkItem>[];
      var hasInvalidItem = false;
      for (final rawItem in rawItems) {
        final item = MergeReviewWorkItem.tryFromJson(rawItem);
        if (item == null) {
          hasInvalidItem = true;
        } else {
          validItems.add(item);
        }
      }
      final uniqueIds = validItems.map((item) => item.issueId).toSet();
      final hasDuplicates = uniqueIds.length != validItems.length;
      final overCapacity = validItems.length > maxItems;
      return _MergeReviewWorklistLoadState(
        items: _canonicalize(validItems),
        writable: !hasInvalidItem && !hasDuplicates && !overCapacity,
      );
    } catch (_) {
      return const _MergeReviewWorklistLoadState(items: [], writable: false);
    }
  }

  void _ensureWritable(_MergeReviewWorklistLoadState state) {
    if (!state.writable) {
      throw StateError(
        'Stored merge review worklist is invalid or exceeds configured '
        'limits; clear it explicitly before mutating.',
      );
    }
  }

  Future<List<MergeReviewWorkItem>> _persistUnlocked(
    Iterable<MergeReviewWorkItem> items,
  ) async {
    final canonical = _canonicalize(items);
    final payload = MergeReviewWorkItemCodec.encode(canonical);
    if (_payloadLength(payload) > maxValueLength) {
      throw StateError(
        'Merge review worklist payload exceeds $maxValueLength bytes.',
      );
    }
    await _repository.setAppMeta(metaKey, payload);
    return canonical;
  }

  List<MergeReviewWorkItem> _canonicalize(
    Iterable<MergeReviewWorkItem> source,
  ) {
    final byIssueId = <String, MergeReviewWorkItem>{};
    for (final item in source) {
      byIssueId[item.issueId] = item;
    }
    final sorted = byIssueId.values.toList()..sort(_compareItems);
    return List<MergeReviewWorkItem>.unmodifiable(sorted.take(maxItems));
  }

  int _compareItems(MergeReviewWorkItem left, MergeReviewWorkItem right) {
    final status = _statusRank(
      left.status,
    ).compareTo(_statusRank(right.status));
    if (status != 0) {
      return status;
    }
    final updatedAt = right.updatedAt.compareTo(left.updatedAt);
    if (updatedAt != 0) {
      return updatedAt;
    }
    return left.issueId.compareTo(right.issueId);
  }

  int _statusRank(MergeReviewWorkItemStatus status) {
    return switch (status) {
      MergeReviewWorkItemStatus.queued => 0,
      MergeReviewWorkItemStatus.deferred => 1,
    };
  }

  int _payloadLength(String payload) => utf8.encode(payload).length;

  static int _validateMaxItems(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'maxItems', 'must be greater than zero');
    }
    return value;
  }

  static int _validateMaxValueLength(int value) {
    final minimum = utf8.encode(MergeReviewWorkItemCodec.emptyPayload).length;
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

  _MergeReviewWorklistQueue _queueForRepository() {
    final existing = _queues[_repository];
    if (existing != null) {
      return existing;
    }
    final created = _MergeReviewWorklistQueue();
    _queues[_repository] = created;
    return created;
  }
}

class _MergeReviewWorklistQueue {
  Future<void> tail = Future<void>.value();
}

class _MergeReviewWorklistLoadState {
  const _MergeReviewWorklistLoadState({
    required this.items,
    required this.writable,
  });

  final List<MergeReviewWorkItem> items;
  final bool writable;
}
