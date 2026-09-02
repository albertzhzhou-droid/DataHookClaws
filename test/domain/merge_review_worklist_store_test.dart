import 'dart:async';
import 'dart:convert';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/merge_review_worklist_store.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:data_hook_claws/src/models/merge_review_work_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewWorklistStore', () {
    test('constructor enforces item and payload limits at runtime', () {
      final minimumPayloadLength = utf8
          .encode(MergeReviewWorkItemCodec.emptyPayload)
          .length;

      for (final maxItems in [0, -1]) {
        expect(
          () => MergeReviewWorklistStore(
            _ControllableMetaRepository(),
            maxItems: maxItems,
          ),
          throwsArgumentError,
          reason: 'maxItems: $maxItems',
        );
      }
      expect(
        () => MergeReviewWorklistStore(
          _ControllableMetaRepository(),
          maxValueLength: minimumPayloadLength - 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewWorklistStore(
          _ControllableMetaRepository(),
          maxValueLength: minimumPayloadLength,
        ),
        returnsNormally,
      );
    });

    test('commits a batch atomically with duplicate issue last-wins', () async {
      final now = DateTime.utc(2026, 8, 30, 12);
      final repository = _ControllableMetaRepository();
      final store = MergeReviewWorklistStore(repository, clock: () => now);
      final alphaIdentity = _identity('alpha');
      final betaIdentity = _identity('beta');
      final alphaInitial = _issue(
        identity: alphaIdentity,
        reason: 'Initial alpha snapshot',
      );
      final alphaWinner = _issue(
        identity: alphaIdentity,
        reason: 'Winning alpha snapshot',
      );

      final snapshot = await store.upsertAll([
        MergeReviewWorklistUpsert(
          issue: alphaInitial,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: _issue(identity: betaIdentity),
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: alphaWinner,
          status: MergeReviewWorkItemStatus.deferred,
        ),
      ]);

      expect(repository.getCalls, 1);
      expect(repository.setCalls, 1);
      expect(snapshot, hasLength(2));
      final alpha = snapshot.singleWhere(
        (item) => item.issueId == alphaIdentity.encode(),
      );
      expect(alpha.status, MergeReviewWorkItemStatus.deferred);
      expect(alpha.reason, 'Winning alpha snapshot');
      expect(alpha.targetSourceRecordId, alphaIdentity.sourceRecordId);
      expect(alpha.createdAt, now);
      expect(alpha.updatedAt, now);
      expect(MergeReviewWorkItemCodec.decode(repository.payload), snapshot);
      expect(() => snapshot.clear(), throwsUnsupportedError);
    });

    test(
      'filters bad persisted items then dedupes, sorts, and limits winners',
      () async {
        final alphaIdentity = _identity('alpha');
        final betaIdentity = _identity('beta');
        final gammaIdentity = _identity('gamma');
        final deltaIdentity = _identity('delta');
        final epsilonIdentity = _identity('epsilon');
        final alphaOld = _storedItem(
          issue: _issue(identity: alphaIdentity, reason: 'Old alpha'),
          status: MergeReviewWorkItemStatus.deferred,
          updatedAt: DateTime.utc(2026, 8, 30, 17),
        );
        final alphaWinner = _storedItem(
          issue: _issue(identity: alphaIdentity, reason: 'Last alpha wins'),
          status: MergeReviewWorkItemStatus.queued,
          updatedAt: DateTime.utc(2026, 8, 30, 13),
        );
        final beta = _storedItem(
          issue: _issue(identity: betaIdentity),
          status: MergeReviewWorkItemStatus.queued,
          updatedAt: DateTime.utc(2026, 8, 30, 15),
        );
        final gamma = _storedItem(
          issue: _issue(identity: gammaIdentity),
          status: MergeReviewWorkItemStatus.queued,
          updatedAt: DateTime.utc(2026, 8, 30, 15),
        );
        final delta = _storedItem(
          issue: _issue(identity: deltaIdentity),
          status: MergeReviewWorkItemStatus.deferred,
          updatedAt: DateTime.utc(2026, 8, 30, 20),
        );
        final epsilon = _storedItem(
          issue: _issue(identity: epsilonIdentity),
          status: MergeReviewWorkItemStatus.deferred,
          updatedAt: DateTime.utc(2026, 8, 30, 19),
        );
        final payload = jsonEncode({
          'schemaVersion': 1,
          'items': [
            alphaOld.toJson(),
            null,
            {'issueId': alphaOld.issueId},
            {...alphaOld.toJson(), 'canonicalFoodId': 'identity-mismatch'},
            beta.toJson(),
            gamma.toJson(),
            delta.toJson(),
            epsilon.toJson(),
            alphaWinner.toJson(),
          ],
        });
        final repository = _ControllableMetaRepository(payload: payload);
        final store = MergeReviewWorklistStore(repository, maxItems: 4);

        final loaded = await store.load();

        final tiedQueuedIds = [beta.issueId, gamma.issueId]..sort();
        expect(loaded.map((item) => item.issueId), [
          ...tiedQueuedIds,
          alphaWinner.issueId,
          delta.issueId,
        ]);
        expect(
          loaded
              .singleWhere((item) => item.issueId == alphaWinner.issueId)
              .reason,
          'Last alpha wins',
        );
        expect(
          loaded.where((item) => item.issueId == alphaWinner.issueId),
          hasLength(1),
        );
        expect(loaded, isNot(contains(epsilon)));
        expect(repository.setCalls, 0, reason: 'load must not repair storage');
        expect(() => loaded.removeLast(), throwsUnsupportedError);
      },
    );

    test(
      'at capacity permits updates but rejects new and mixed batches atomically',
      () async {
        var hour = 12;
        final repository = _ControllableMetaRepository();
        final store = MergeReviewWorklistStore(
          repository,
          maxItems: 2,
          clock: () => DateTime.utc(2026, 8, 30, hour++),
        );
        final alphaIdentity = _identity('alpha');
        final betaIdentity = _identity('beta');
        final gammaIdentity = _identity('gamma');
        final initial = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(identity: alphaIdentity),
            status: MergeReviewWorkItemStatus.queued,
          ),
          MergeReviewWorklistUpsert(
            issue: _issue(identity: betaIdentity),
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);
        final alphaCreatedAt = initial
            .singleWhere((item) => item.issueId == alphaIdentity.encode())
            .createdAt;

        final updated = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(
              identity: alphaIdentity,
              reason: 'Updated while full',
            ),
            status: MergeReviewWorkItemStatus.deferred,
          ),
        ]);
        final updatedAlpha = updated.singleWhere(
          (item) => item.issueId == alphaIdentity.encode(),
        );
        expect(updatedAlpha.createdAt, alphaCreatedAt);
        expect(updatedAlpha.updatedAt, DateTime.utc(2026, 8, 30, 13));
        expect(updatedAlpha.reason, 'Updated while full');
        final payloadBeforeRejectedBatches = repository.payload;
        final writesBeforeRejectedBatches = repository.setCalls;

        await expectLater(
          store.upsertAll([
            MergeReviewWorklistUpsert(
              issue: _issue(
                identity: alphaIdentity,
                reason: 'Must not partially commit',
              ),
              status: MergeReviewWorkItemStatus.queued,
            ),
            MergeReviewWorklistUpsert(
              issue: _issue(identity: gammaIdentity),
              status: MergeReviewWorkItemStatus.queued,
            ),
          ]),
          throwsStateError,
        );
        await expectLater(
          store.upsertAll([
            MergeReviewWorklistUpsert(
              issue: _issue(identity: gammaIdentity),
              status: MergeReviewWorkItemStatus.deferred,
            ),
          ]),
          throwsStateError,
        );

        expect(repository.payload, payloadBeforeRejectedBatches);
        expect(repository.setCalls, writesBeforeRejectedBatches);
        expect(
          (await store.load())
              .singleWhere((item) => item.issueId == alphaIdentity.encode())
              .reason,
          'Updated while full',
        );
      },
    );

    test(
      'clock rollback preserves an existing item updatedAt and order',
      () async {
        final clockValues = [
          DateTime.utc(2026, 8, 30, 12),
          DateTime.utc(2026, 8, 30, 14),
          DateTime.utc(2026, 8, 30, 15),
          DateTime.utc(2026, 8, 30, 13),
        ];
        var clockIndex = 0;
        final repository = _ControllableMetaRepository();
        final store = MergeReviewWorklistStore(
          repository,
          clock: () => clockValues[clockIndex++],
        );
        final alphaIdentity = _identity('alpha-rollback');
        final betaIdentity = _identity('beta-rollback');
        final alpha = _issue(identity: alphaIdentity);
        final beta = _issue(identity: betaIdentity);

        final initial = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: alpha,
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);
        final alphaCreatedAt = initial.single.createdAt;
        await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: beta,
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);
        final laterUpdate = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(
              identity: alphaIdentity,
              reason: 'Later successful update',
            ),
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);
        final laterUpdatedAt = laterUpdate
            .singleWhere((item) => item.issueId == alpha.id)
            .updatedAt;
        expect(laterUpdatedAt, DateTime.utc(2026, 8, 30, 15));

        final rollbackUpdate = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(
              identity: alphaIdentity,
              reason: 'Snapshot accepted during clock rollback',
            ),
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);

        final persistedAlpha = rollbackUpdate.singleWhere(
          (item) => item.issueId == alpha.id,
        );
        expect(persistedAlpha.createdAt, alphaCreatedAt);
        expect(persistedAlpha.updatedAt, laterUpdatedAt);
        expect(
          persistedAlpha.reason,
          'Snapshot accepted during clock rollback',
        );
        expect(rollbackUpdate.map((item) => item.issueId), [alpha.id, beta.id]);
        expect(
          MergeReviewWorkItemCodec.decode(repository.payload),
          rollbackUpdate,
        );
        expect(await store.load(), rollbackUpdate);
      },
    );

    test('rejects an oversized update without replacing prior data', () async {
      final repository = _ControllableMetaRepository();
      final identity = _identity('alpha');
      await MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      ).upsertAll([
        MergeReviewWorklistUpsert(
          issue: _issue(identity: identity),
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      final originalPayload = repository.payload!;
      final originalPayloadBytes = utf8.encode(originalPayload).length;
      final writesBeforeRejectedUpdate = repository.setCalls;
      final limitedStore = MergeReviewWorklistStore(
        repository,
        maxValueLength: originalPayloadBytes,
        clock: () => DateTime.utc(2026, 8, 30, 13),
      );

      await expectLater(
        limitedStore.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(
              identity: identity,
              reason: List.filled(500, '食').join(),
            ),
            status: MergeReviewWorkItemStatus.deferred,
          ),
        ]),
        throwsStateError,
      );

      expect(repository.payload, originalPayload);
      expect(repository.setCalls, writesBeforeRejectedUpdate);
    });

    test(
      'oversized storage blocks mutation until explicit clear recovers it',
      () async {
        const maxValueLength = 2048;
        final repository = _ControllableMetaRepository(
          payload: List.filled(maxValueLength + 1, 'x').join(),
        );
        final store = MergeReviewWorklistStore(
          repository,
          maxValueLength: maxValueLength,
          clock: () => DateTime.utc(2026, 8, 30, 12),
        );

        expect(await store.load(), isEmpty);
        expect(repository.setCalls, 0);

        await expectLater(
          store.upsertAll([
            MergeReviewWorklistUpsert(
              issue: _issue(identity: _identity('blocked')),
              status: MergeReviewWorkItemStatus.queued,
            ),
          ]),
          throwsStateError,
        );
        expect(repository.setCalls, 0);

        await store.clear();
        final recovered = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(identity: _identity('recovered')),
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);

        expect(recovered, hasLength(1));
        expect(repository.setCalls, 2);
        expect(
          utf8.encode(repository.payload!).length,
          lessThanOrEqualTo(maxValueLength),
        );
        expect(MergeReviewWorkItemCodec.decode(repository.payload), recovered);
      },
    );

    test(
      'oversized whitespace loads empty but blocks writes until clear',
      () async {
        const maxValueLength = 2048;
        final oversizedWhitespace = List.filled(maxValueLength + 1, ' ').join();
        final repository = _ControllableMetaRepository(
          payload: oversizedWhitespace,
        );
        final store = MergeReviewWorklistStore(
          repository,
          maxValueLength: maxValueLength,
          clock: () => DateTime.utc(2026, 8, 30, 12),
        );

        expect(await store.load(), isEmpty);
        await expectLater(
          store.upsertAll([
            MergeReviewWorklistUpsert(
              issue: _issue(identity: _identity('whitespace-blocked')),
              status: MergeReviewWorkItemStatus.queued,
            ),
          ]),
          throwsStateError,
        );
        expect(repository.payload, oversizedWhitespace);
        expect(repository.setCalls, 0);

        await store.clear();
        final recovered = await store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: _issue(identity: _identity('whitespace-recovered')),
            status: MergeReviewWorkItemStatus.queued,
          ),
        ]);
        expect(recovered, hasLength(1));
        expect(repository.setCalls, 2);
        expect(MergeReviewWorkItemCodec.decode(repository.payload), recovered);
      },
    );

    test(
      'mutations reject malformed, duplicate, and over-cap stored state',
      () async {
        final alpha = _storedItem(
          issue: _issue(identity: _identity('persisted-alpha')),
          status: MergeReviewWorkItemStatus.queued,
          updatedAt: DateTime.utc(2026, 8, 30, 12),
        );
        final beta = _storedItem(
          issue: _issue(identity: _identity('persisted-beta')),
          status: MergeReviewWorkItemStatus.queued,
          updatedAt: DateTime.utc(2026, 8, 30, 13),
        );
        final gamma = _storedItem(
          issue: _issue(identity: _identity('persisted-gamma')),
          status: MergeReviewWorkItemStatus.deferred,
          updatedAt: DateTime.utc(2026, 8, 30, 14),
        );
        final cases = <String, String>{
          'malformed envelope': '{bad',
          'unsupported envelope': '{"schemaVersion":2,"items":[]}',
          'invalid item': jsonEncode({
            'schemaVersion': 1,
            'items': [
              alpha.toJson(),
              {'bad': true},
            ],
          }),
          'duplicate identity': MergeReviewWorkItemCodec.encode([alpha, alpha]),
          'over capacity': MergeReviewWorkItemCodec.encode([
            alpha,
            beta,
            gamma,
          ]),
        };

        for (final entry in cases.entries) {
          final repository = _ControllableMetaRepository(payload: entry.value);
          final store = MergeReviewWorklistStore(
            repository,
            maxItems: 2,
            clock: () => DateTime.utc(2026, 8, 30, 15),
          );
          await store.load();

          await expectLater(
            store.upsertAll([
              MergeReviewWorklistUpsert(
                issue: _issue(identity: _identity('new-${entry.key}')),
                status: MergeReviewWorkItemStatus.queued,
              ),
            ]),
            throwsStateError,
            reason: entry.key,
          );
          await expectLater(
            store.remove(alpha.issueId),
            throwsStateError,
            reason: entry.key,
          );
          expect(
            repository.setCalls,
            0,
            reason: '${entry.key} must require explicit clear',
          );
          expect(repository.payload, entry.value, reason: entry.key);
        }
      },
    );

    test('remove, removeAll, and clear are idempotent', () async {
      final repository = _ControllableMetaRepository();
      final store = MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final alpha = _issue(identity: _identity('alpha'));
      final beta = _issue(identity: _identity('beta'));
      final gamma = _issue(identity: _identity('gamma'));
      final unknown = _issue(identity: _identity('unknown'));
      await store.upsertAll([
        for (final issue in [alpha, beta, gamma])
          MergeReviewWorklistUpsert(
            issue: issue,
            status: MergeReviewWorkItemStatus.queued,
          ),
      ]);
      final writesAfterSeed = repository.setCalls;

      expect(await store.remove(unknown.id), hasLength(3));
      expect(await store.removeAll(const []), hasLength(3));
      expect(repository.setCalls, writesAfterSeed);

      final remaining = await store.removeAll([alpha.id, alpha.id, beta.id]);
      expect(remaining.map((item) => item.issueId), [gamma.id]);
      expect(repository.setCalls, writesAfterSeed + 1);

      expect(await store.remove(alpha.id), remaining);
      expect(repository.setCalls, writesAfterSeed + 1);

      await store.clear();
      expect(repository.payload, MergeReviewWorkItemCodec.emptyPayload);
      await store.clear();
      expect(repository.payload, MergeReviewWorkItemCodec.emptyPayload);
      expect(await store.load(), isEmpty);
    });

    test('serializes mutations across stores sharing one repository', () async {
      final repository = _ControllableMetaRepository(blockFirstWrite: true);
      final firstStore = MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final secondStore = MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 13),
      );
      final alpha = _issue(identity: _identity('alpha'));
      final beta = _issue(identity: _identity('beta'));

      final firstMutation = firstStore.upsertAll([
        MergeReviewWorklistUpsert(
          issue: alpha,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await repository.firstWriteStarted.future;
      final secondMutation = secondStore.upsertAll([
        MergeReviewWorklistUpsert(
          issue: beta,
          status: MergeReviewWorkItemStatus.deferred,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(repository.getCalls, 1);
      expect(repository.setCalls, 1);
      repository.releaseFirstWrite.complete();
      await Future.wait([firstMutation, secondMutation]);

      expect(repository.getCalls, 2);
      expect(repository.setCalls, 2);
      expect(
        MergeReviewWorkItemCodec.decode(
          repository.payload,
        ).map((item) => item.issueId).toSet(),
        {alpha.id, beta.id},
      );
    });

    test('a failed read does not poison later queued work', () async {
      final repository = _ControllableMetaRepository(failReadsRemaining: 1);
      final store = MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );

      final failedLoad = store.load();
      final failedExpectation = expectLater(failedLoad, throwsStateError);
      final succeedingMutation = store.upsertAll([
        MergeReviewWorklistUpsert(
          issue: _issue(identity: _identity('after-read-failure')),
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);

      await failedExpectation;
      final recovered = await succeedingMutation;
      expect(recovered, hasLength(1));
      expect(repository.getCalls, 2);
      expect(repository.setCalls, 1);
    });

    test('a failed write does not poison later queued work', () async {
      final repository = _ControllableMetaRepository(failWritesRemaining: 1);
      final store = MergeReviewWorklistStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final alpha = _issue(identity: _identity('alpha'));
      final beta = _issue(identity: _identity('beta'));

      final failedMutation = store.upsertAll([
        MergeReviewWorklistUpsert(
          issue: alpha,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      final failedExpectation = expectLater(failedMutation, throwsStateError);
      final succeedingMutation = store.upsertAll([
        MergeReviewWorklistUpsert(
          issue: beta,
          status: MergeReviewWorkItemStatus.deferred,
        ),
      ]);

      await failedExpectation;
      final recovered = await succeedingMutation;
      expect(recovered.map((item) => item.issueId), [beta.id]);
      expect(repository.getCalls, 2);
      expect(repository.setCalls, 2);
      expect(
        MergeReviewWorkItemCodec.decode(repository.payload).single.issueId,
        beta.id,
      );
    });

    test('invalid caller issues and ids perform zero repository I/O', () async {
      final repository = _ControllableMetaRepository();
      final store = MergeReviewWorklistStore(repository);
      final validIdentity = _identity('valid');
      final validIssue = _issue(identity: validIdentity);
      final invalidIssue = _issue(
        identity: validIdentity,
        canonicalFoodId: 'identity-mismatch',
      );

      await expectLater(
        store.upsertAll([
          MergeReviewWorklistUpsert(
            issue: validIssue,
            status: MergeReviewWorkItemStatus.queued,
          ),
          MergeReviewWorklistUpsert(
            issue: invalidIssue,
            status: MergeReviewWorkItemStatus.deferred,
          ),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        store.removeAll([validIssue.id, 'legacy-derived-id']),
        throwsArgumentError,
      );
      await expectLater(store.remove(''), throwsArgumentError);

      expect(repository.getCalls, 0);
      expect(repository.setCalls, 0);
    });
  });
}

MergeReviewIssueIdentity _identity(String suffix) {
  return MergeReviewIssueIdentity(
    canonicalFoodId: 'canonical-$suffix',
    sourceRecordId: 'identity-source-$suffix',
    type: MergeReviewIssueType.categoryConflictCandidate,
    subjectKey: 'candidate:canonical-suggestion-$suffix',
  );
}

MergeReviewIssue _issue({
  required MergeReviewIssueIdentity identity,
  String? canonicalFoodId,
  String? targetSourceRecordId,
  String? reason,
}) {
  return MergeReviewIssue(
    id: identity.encode(),
    canonicalFoodId: canonicalFoodId ?? identity.canonicalFoodId,
    sourceRecordId: targetSourceRecordId ?? identity.sourceRecordId,
    type: identity.type,
    severity: MergeReviewSeverity.warning,
    reason: reason ?? 'Review ${identity.subjectKey}',
    candidateSummary: 'Candidate ${identity.subjectKey}',
    createdAt: DateTime.utc(2026, 8, 30, 10),
    suggestedCanonicalFoodId: 'canonical-suggestion',
  );
}

MergeReviewWorkItem _storedItem({
  required MergeReviewIssue issue,
  required MergeReviewWorkItemStatus status,
  required DateTime updatedAt,
}) {
  return MergeReviewWorkItem.fromIssue(
    issue: issue,
    status: status,
    createdAt: DateTime.utc(2026, 8, 30, 8),
    updatedAt: updatedAt,
  );
}

class _ControllableMetaRepository extends MemoryFoodRepository {
  _ControllableMetaRepository({
    this.payload,
    this.blockFirstWrite = false,
    this.failReadsRemaining = 0,
    this.failWritesRemaining = 0,
  });

  String? payload;
  final bool blockFirstWrite;
  int failReadsRemaining;
  int failWritesRemaining;
  int getCalls = 0;
  int setCalls = 0;
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key != MergeReviewWorklistStore.metaKey) {
      return super.getAppMeta(key);
    }
    getCalls += 1;
    if (failReadsRemaining > 0) {
      failReadsRemaining -= 1;
      throw StateError('simulated app_meta read failure');
    }
    return payload;
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key != MergeReviewWorklistStore.metaKey) {
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
