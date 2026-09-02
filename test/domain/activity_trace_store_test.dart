import 'dart:async';
import 'dart:convert';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/activity_trace_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityTraceStore', () {
    test('constructor enforces item and payload limits at runtime', () {
      final repository = _ControllableMetaRepository();
      for (final maxItems in [0, -1]) {
        expect(
          () => ActivityTraceStore(repository, maxItems: maxItems),
          throwsArgumentError,
          reason: 'maxItems: $maxItems',
        );
      }
      expect(
        () => ActivityTraceStore(repository, maxValueLength: 1),
        throwsArgumentError,
      );
      expect(
        () => ActivityTraceStore(repository, maxValueLength: 2),
        returnsNormally,
      );
    });

    test('serializes concurrent appends across store instances', () async {
      final repository = _ControllableMetaRepository(blockFirstWrite: true);
      final firstStore = ActivityTraceStore(repository);
      final secondStore = ActivityTraceStore(repository);

      final firstAppend = firstStore.append(
        action: 'search',
        summary: 'A',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 1),
      );
      await repository.firstWriteStarted.future;
      final secondAppend = secondStore.append(
        action: 'export',
        summary: 'B',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 2),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.getCalls, 1);
      expect(repository.setCalls, 1);
      repository.releaseFirstWrite.complete();
      await Future.wait([firstAppend, secondAppend]);

      expect(repository.getCalls, 2);
      expect(repository.setCalls, 2);
      expect(_summaries(repository.payload), ['B', 'A']);
    });

    test('broadcasts persisted snapshots across store instances', () async {
      final repository = _ControllableMetaRepository();
      final observer = ActivityTraceStore(repository);
      final writer = ActivityTraceStore(repository);
      final changed = observer.changes.first;

      await writer.append(
        action: 'governance',
        summary: 'merged',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 1),
      );

      expect((await changed).map((record) => record['summary']), ['merged']);
    });

    test('malformed and unsupported payloads fail open', () async {
      for (final payload in ['{bad', '{}', '[42, null, "text"]']) {
        final repository = _ControllableMetaRepository(payload: payload);
        final store = ActivityTraceStore(repository);

        await store.append(
          action: 'search',
          summary: 'A',
          details: const {},
          occurredAt: DateTime.utc(2026, 1, 1),
        );
        await store.append(
          action: 'export',
          summary: 'B',
          details: const {},
          occurredAt: DateTime.utc(2026, 1, 2),
        );

        expect(_summaries(repository.payload), ['B', 'A']);
      }
    });

    test(
      'invalid map entries do not crowd valid history out of the limit',
      () async {
        final valid = _record('valid', DateTime.utc(2026, 1, 1));
        final repository = _ControllableMetaRepository(
          payload: jsonEncode([
            ...List.generate(
              12,
              (index) => {
                'occurredAt': 'invalid-$index',
                'action': 'search',
                'summary': 'invalid',
              },
            ),
            valid,
          ]),
        );

        final records = await ActivityTraceStore(repository).load();

        expect(records.map((record) => record['summary']), ['valid']);
      },
    );

    test('evicts only oldest records to satisfy the payload cap', () async {
      final oldest = _record('oldest', DateTime.utc(2026, 1, 1));
      final previous = _record('previous', DateTime.utc(2026, 1, 2));
      final newest = _record('newest', DateTime.utc(2026, 1, 3));
      final maxLength = jsonEncode([newest, previous]).length;
      final repository = _ControllableMetaRepository(
        payload: jsonEncode([previous, oldest]),
      );
      final store = ActivityTraceStore(repository, maxValueLength: maxLength);

      await store.append(
        action: 'search',
        summary: 'newest',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 3),
      );

      expect(repository.payload.length, lessThanOrEqualTo(maxLength));
      expect(_summaries(repository.payload), ['newest', 'previous']);
    });

    test('oversized new record preserves prior encodable history', () async {
      final existing = _record('existing', DateTime.utc(2026, 1, 1));
      final maxLength = jsonEncode([existing]).length;
      final repository = _ControllableMetaRepository(
        payload: jsonEncode([existing]),
      );
      final store = ActivityTraceStore(repository, maxValueLength: maxLength);

      await store.append(
        action: 'export',
        summary: 'oversized',
        details: {'value': List.filled(1000, 'x').join()},
        occurredAt: DateTime.utc(2026, 1, 2),
      );

      expect(_summaries(repository.payload), ['existing']);
    });

    test('oversized stored payload is replaced by a small append', () async {
      final repository = _ControllableMetaRepository(
        payload: jsonEncode([
          {
            ..._record('oversized-existing', DateTime.utc(2026, 1, 1)),
            'details': {'value': List.filled(200, 'x').join()},
          },
        ]),
      );
      final store = ActivityTraceStore(repository, maxValueLength: 120);

      expect(await store.load(), isEmpty);
      await store.append(
        action: 'search',
        summary: 'small',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 2),
      );

      expect(_summaries(repository.payload), ['small']);
    });

    test('oversized first record persists an empty trace', () async {
      final repository = _ControllableMetaRepository();
      final store = ActivityTraceStore(repository, maxValueLength: 120);

      final records = await store.append(
        action: 'search',
        summary: 'oversized',
        details: {'value': List.filled(1000, 'x').join()},
        occurredAt: DateTime.utc(2026, 1, 1),
      );

      expect(records, isEmpty);
      expect(repository.payload, '[]');
    });

    test('enforces the payload cap in UTF-8 bytes', () async {
      final repository = _ControllableMetaRepository();
      final probe = _record('😀', DateTime.utc(2026, 1, 1));
      final encodedProbe = jsonEncode([probe]);
      final utf8Length = utf8.encode(encodedProbe).length;
      expect(utf8Length, greaterThan(encodedProbe.length));
      final store = ActivityTraceStore(
        repository,
        maxValueLength: utf8Length - 1,
      );

      final records = await store.append(
        action: 'search',
        summary: '😀',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 1),
      );

      expect(records, isEmpty);
      expect(
        utf8.encode(repository.payload).length,
        lessThanOrEqualTo(utf8Length - 1),
      );
    });

    test('failed write does not poison later queued appends', () async {
      final repository = _ControllableMetaRepository(failWritesRemaining: 1);
      final store = ActivityTraceStore(repository);
      final firstAppend = store.append(
        action: 'search',
        summary: 'A',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 1),
      );
      final firstExpectation = expectLater(firstAppend, throwsStateError);
      final secondAppend = store.append(
        action: 'export',
        summary: 'B',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 2),
      );

      await firstExpectation;
      await secondAppend;

      expect(repository.setCalls, 2);
      expect(_summaries(repository.payload), ['B']);
    });

    test('keeps newest records within the item limit', () async {
      final repository = _ControllableMetaRepository();
      final store = ActivityTraceStore(repository, maxItems: 3);

      for (var index = 0; index < 4; index++) {
        await store.append(
          action: 'search',
          summary: String.fromCharCode('A'.codeUnitAt(0) + index),
          details: const {},
          occurredAt: DateTime.utc(2026, 1, index + 1),
        );
      }

      expect(_summaries(repository.payload), ['D', 'C', 'B']);
    });

    test('clear waits behind an in-flight append', () async {
      final repository = _ControllableMetaRepository(blockFirstWrite: true);
      final store = ActivityTraceStore(repository);
      final append = store.append(
        action: 'search',
        summary: 'A',
        details: const {},
        occurredAt: DateTime.utc(2026, 1, 1),
      );
      await repository.firstWriteStarted.future;
      final clear = store.clear();
      await Future<void>.delayed(Duration.zero);

      expect(repository.setCalls, 1);
      repository.releaseFirstWrite.complete();
      await append;
      await clear;

      expect(repository.setCalls, 2);
      expect(repository.payload, '[]');
    });
  });
}

Map<String, Object?> _record(String summary, DateTime occurredAt) {
  return {
    'occurredAt': occurredAt.toIso8601String(),
    'action': 'search',
    'summary': summary,
    'details': <String, Object?>{},
  };
}

List<String> _summaries(String payload) {
  final decoded = jsonDecode(payload) as List<dynamic>;
  return decoded
      .cast<Map<String, dynamic>>()
      .map((record) => record['summary'] as String)
      .toList(growable: false);
}

class _ControllableMetaRepository extends MemoryFoodRepository {
  _ControllableMetaRepository({
    String? payload,
    this.blockFirstWrite = false,
    this.failWritesRemaining = 0,
  }) : payload = payload ?? '[]';

  String payload;
  final bool blockFirstWrite;
  int failWritesRemaining;
  int getCalls = 0;
  int setCalls = 0;
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key != ActivityTraceStore.metaKey) {
      return super.getAppMeta(key);
    }
    getCalls += 1;
    return payload;
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key != ActivityTraceStore.metaKey) {
      return super.setAppMeta(key, value);
    }
    setCalls += 1;
    if (blockFirstWrite && setCalls == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    if (failWritesRemaining > 0) {
      failWritesRemaining -= 1;
      throw StateError('simulated app_meta write failure');
    }
    payload = value;
  }
}
