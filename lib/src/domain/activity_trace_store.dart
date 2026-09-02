import 'dart:async';
import 'dart:convert';

import '../data/food_repository.dart';

class ActivityTraceStore {
  ActivityTraceStore(
    this._repository, {
    int maxItems = 12,
    int maxValueLength = 1048576,
  }) : maxItems = _validateMaxItems(maxItems),
       maxValueLength = _validateMaxValueLength(maxValueLength);

  static const String metaKey = 'activity_trace_v1';
  static final Expando<_ActivityTraceQueue> _queues =
      Expando<_ActivityTraceQueue>('activity-trace-queues');

  final FoodRepository _repository;
  final int maxItems;
  final int maxValueLength;

  Stream<List<Map<String, Object?>>> get changes =>
      _queueForRepository().changes.stream;

  Future<List<Map<String, Object?>>> load() {
    return _runSerialized(() async {
      final rawValue = await _repository.getAppMeta(metaKey);
      return _decode(rawValue).take(maxItems).toList(growable: false);
    });
  }

  Future<List<Map<String, Object?>>> append({
    required String action,
    required String summary,
    required Map<String, Object?> details,
    DateTime? occurredAt,
  }) {
    final entry = <String, Object?>{
      'occurredAt': (occurredAt ?? DateTime.now()).toIso8601String(),
      'action': action,
      'summary': summary.trim(),
      'details': Map<String, Object?>.from(details),
    };

    return _runSerialized(() async {
      final rawValue = await _repository.getAppMeta(metaKey);
      final existing = _decode(rawValue);
      final next = <Map<String, Object?>>[
        entry,
        ...existing,
      ].take(maxItems).toList(growable: false);
      var batch = _fit(next);
      if (batch.records.isEmpty && existing.isNotEmpty) {
        batch = _fit(existing);
      }
      await _repository.setAppMeta(metaKey, batch.payload);
      _queueForRepository().changes.add(batch.records);
      return batch.records;
    });
  }

  Future<void> clear() {
    return _runSerialized(() async {
      await _repository.setAppMeta(metaKey, '[]');
      _queueForRepository().changes.add(const []);
    });
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

  _ActivityTraceQueue _queueForRepository() {
    final existing = _queues[_repository];
    if (existing != null) {
      return existing;
    }
    final created = _ActivityTraceQueue();
    _queues[_repository] = created;
    return created;
  }

  List<Map<String, Object?>> _decode(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }
    if (_payloadLength(rawValue) > maxValueLength) {
      return const [];
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List<dynamic>) {
        return const [];
      }
      final records = <Map<String, Object?>>[];
      for (final value in decoded) {
        if (value is! Map) {
          continue;
        }
        final record = <String, Object?>{};
        for (final key in value.keys) {
          record[key.toString()] = value[key];
        }
        if (!_isValidRecord(record)) {
          continue;
        }
        final rawDetails = record['details'];
        final details = <String, Object?>{};
        if (rawDetails is Map) {
          for (final key in rawDetails.keys) {
            final normalizedKey = key.toString();
            if (normalizedKey.trim().isEmpty) {
              continue;
            }
            details[normalizedKey] = rawDetails[key];
          }
        }
        record['details'] = details;
        records.add(record);
      }
      return records;
    } catch (_) {
      return const [];
    }
  }

  bool _isValidRecord(Map<String, Object?> record) {
    final action = record['action'];
    final summary = record['summary'];
    final occurredAt = record['occurredAt'];
    return action is String &&
        summary is String &&
        occurredAt is String &&
        DateTime.tryParse(occurredAt) != null;
  }

  _EncodedTraceBatch _fit(List<Map<String, Object?>> records) {
    final compact = records.take(maxItems).toList(growable: true);
    while (compact.isNotEmpty) {
      final payload = jsonEncode(compact);
      if (_payloadLength(payload) <= maxValueLength) {
        return _EncodedTraceBatch(
          payload: payload,
          records: List<Map<String, Object?>>.unmodifiable(compact),
        );
      }
      compact.removeLast();
    }
    return const _EncodedTraceBatch(payload: '[]', records: []);
  }

  int _payloadLength(String payload) => utf8.encode(payload).length;

  static int _validateMaxItems(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'maxItems', 'must be greater than zero');
    }
    return value;
  }

  static int _validateMaxValueLength(int value) {
    const minimum = 2;
    if (value < minimum) {
      throw ArgumentError.value(
        value,
        'maxValueLength',
        'must be at least $minimum UTF-8 bytes',
      );
    }
    return value;
  }
}

class _ActivityTraceQueue {
  Future<void> tail = Future<void>.value();
  final StreamController<List<Map<String, Object?>>> changes =
      StreamController<List<Map<String, Object?>>>.broadcast(sync: true);
}

class _EncodedTraceBatch {
  const _EncodedTraceBatch({required this.payload, required this.records});

  final String payload;
  final List<Map<String, Object?>> records;
}
