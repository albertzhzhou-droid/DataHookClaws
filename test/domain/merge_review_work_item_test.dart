import 'dart:convert';

import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:data_hook_claws/src/models/merge_review_work_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewWorkItem', () {
    test('round-trips Unicode snapshots with deterministic encoding', () {
      final identity = MergeReviewIssueIdentity(
        canonicalFoodId: 'canonical:食物/🍎',
        sourceRecordId: '',
        type: MergeReviewIssueType.multiSourceNutrientVariance,
        subjectKey: 'nutrient:维生素 C|mg/100 g',
      );
      final item = MergeReviewWorkItem(
        issueId: identity.encode(),
        canonicalFoodId: identity.canonicalFoodId,
        identitySourceRecordId: identity.sourceRecordId,
        targetSourceRecordId: 'source:可执行/A',
        type: identity.type,
        subjectKey: identity.subjectKey,
        status: MergeReviewWorkItemStatus.queued,
        suggestedCanonicalFoodId: 'canonical:建议/B',
        reason: '维生素 C differs across sources: A/B.',
        candidateSummary: '来源甲: 12 mg | 来源乙: 18 mg',
        issueCreatedAt: DateTime.parse('2026-08-30T08:00:00-04:00'),
        createdAt: DateTime.parse('2026-08-30T09:00:00-04:00'),
        updatedAt: DateTime.parse('2026-08-30T10:00:00-04:00'),
      );

      final firstPayload = MergeReviewWorkItemCodec.encode([item]);
      final secondPayload = MergeReviewWorkItemCodec.encode([item]);
      final decoded = MergeReviewWorkItemCodec.decode(firstPayload);

      expect(firstPayload, secondPayload);
      expect(decoded, [item]);
      expect(decoded.single.identity, identity);
      expect(decoded.single.issueCreatedAt.isUtc, isTrue);
      expect(decoded.single.createdAt.isUtc, isTrue);
      expect(decoded.single.updatedAt.isUtc, isTrue);
      expect(() => decoded.clear(), throwsUnsupportedError);
      expect(
        MergeReviewWorkItemCodec.encode(const []),
        MergeReviewWorkItemCodec.emptyPayload,
      );
    });

    test('fromIssue preserves structured id and separates source roles', () {
      final identity = MergeReviewIssueIdentity(
        canonicalFoodId: 'canonical-1',
        sourceRecordId: '',
        type: MergeReviewIssueType.multiSourceNutrientVariance,
        subjectKey: 'nutrient:sodium',
      );
      final issue = _issue(
        identity: identity,
        sourceRecordId: 'first-actionable-source',
        reason: 'Sodium differs.',
        candidateSummary: 'Source A: 2 mg | Source B: 5 mg',
      );
      final createdAt = DateTime.utc(2026, 8, 30, 12);
      final updatedAt = DateTime.utc(2026, 8, 30, 13);

      final item = MergeReviewWorkItem.fromIssue(
        issue: issue,
        createdAt: createdAt,
        updatedAt: updatedAt,
        status: MergeReviewWorkItemStatus.deferred,
      );

      expect(item.issueId, issue.id);
      expect(item.identitySourceRecordId, isEmpty);
      expect(item.targetSourceRecordId, 'first-actionable-source');
      expect(item.canonicalFoodId, issue.canonicalFoodId);
      expect(item.type, issue.type);
      expect(item.subjectKey, 'nutrient:sodium');
      expect(item.reason, issue.reason);
      expect(item.candidateSummary, issue.candidateSummary);
      expect(item.issueCreatedAt, issue.createdAt.toUtc());
      expect(item.createdAt, createdAt);
      expect(item.updatedAt, updatedAt);
      expect(item.status, MergeReviewWorkItemStatus.deferred);
    });

    test(
      'fromIssue refreshes snapshots while preserving supplied creation',
      () {
        final identity = _identity(
          sourceRecordId: '',
          type: MergeReviewIssueType.multiSourceNutrientVariance,
          subjectKey: 'nutrient:protein',
        );
        final initial = MergeReviewWorkItem.fromIssue(
          issue: _issue(identity: identity),
          createdAt: DateTime.utc(2026, 8, 30, 12),
        );
        final refreshedIssue = _issue(
          identity: identity,
          sourceRecordId: 'new-target-source',
          suggestedCanonicalFoodId: 'new-suggestion',
          reason: 'Updated reason',
          candidateSummary: 'Updated evidence',
          createdAt: DateTime.utc(2026, 8, 30, 13),
        );

        final refreshed = MergeReviewWorkItem.fromIssue(
          issue: refreshedIssue,
          createdAt: initial.createdAt,
          updatedAt: DateTime.utc(2026, 8, 30, 14),
          status: MergeReviewWorkItemStatus.deferred,
        );

        expect(refreshed.createdAt, initial.createdAt);
        expect(refreshed.updatedAt, DateTime.utc(2026, 8, 30, 14));
        expect(refreshed.status, MergeReviewWorkItemStatus.deferred);
        expect(refreshed.issueId, initial.issueId);
        expect(refreshed.targetSourceRecordId, 'new-target-source');
        expect(refreshed.suggestedCanonicalFoodId, 'new-suggestion');
        expect(refreshed.reason, 'Updated reason');
        expect(refreshed.candidateSummary, 'Updated evidence');
        expect(refreshed.issueCreatedAt, refreshedIssue.createdAt);
      },
    );

    test('fromIssue rejects synthetic and mismatched structured ids', () {
      final validIdentity = _identity();
      expect(
        () => MergeReviewWorkItem.fromIssue(
          issue: _issue(identity: validIdentity, id: 'legacy-derived-id'),
          createdAt: DateTime.utc(2026, 8, 30),
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewWorkItem.fromIssue(
          issue: _issue(
            identity: validIdentity,
            canonicalFoodId: 'different-canonical',
          ),
          createdAt: DateTime.utc(2026, 8, 30),
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewWorkItem.fromIssue(
          issue: _issue(
            identity: validIdentity,
            type: MergeReviewIssueType.createdWithCandidates,
          ),
          createdAt: DateTime.utc(2026, 8, 30),
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewWorkItem.fromIssue(
          issue: _issue(
            identity: validIdentity,
            sourceRecordId: 'different-source',
          ),
          createdAt: DateTime.utc(2026, 8, 30),
        ),
        throwsArgumentError,
      );
      final invalidNutrientIdentity = _identity(
        sourceRecordId: 'source-1',
        type: MergeReviewIssueType.multiSourceNutrientVariance,
        subjectKey: 'nutrient:protein',
      );
      expect(
        () => MergeReviewWorkItem.fromIssue(
          issue: _issue(identity: invalidNutrientIdentity),
          createdAt: DateTime.utc(2026, 8, 30),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects every identity snapshot mismatch', () {
      final identity = _identity();
      final constructors = <MergeReviewWorkItem Function()>[
        () => _item(identity: identity, canonicalFoodId: 'different'),
        () => _item(identity: identity, identitySourceRecordId: 'different'),
        () => _item(
          identity: identity,
          type: MergeReviewIssueType.createdWithCandidates,
        ),
        () => _item(identity: identity, subjectKey: 'different'),
      ];

      for (final constructor in constructors) {
        expect(constructor, throwsArgumentError);
      }

      expect(
        () => _item(
          identity: identity,
          targetSourceRecordId: 'independent-target',
        ),
        throwsArgumentError,
      );
      final nutrientIdentity = _identity(
        sourceRecordId: '',
        type: MergeReviewIssueType.multiSourceNutrientVariance,
        subjectKey: 'nutrient:protein',
      );
      expect(
        _item(
          identity: nutrientIdentity,
          targetSourceRecordId: 'independent-target',
        ).targetSourceRecordId,
        'independent-target',
      );
      expect(
        () => _item(
          identity: _identity(
            sourceRecordId: 'source-1',
            type: MergeReviewIssueType.multiSourceNutrientVariance,
            subjectKey: 'nutrient:protein',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith changes status/time without replacing snapshots', () {
      final original = _item();
      final deferred = original.copyWith(
        status: MergeReviewWorkItemStatus.deferred,
        updatedAt: DateTime.utc(2026, 8, 30, 15),
      );

      expect(deferred.status, MergeReviewWorkItemStatus.deferred);
      expect(deferred.updatedAt, DateTime.utc(2026, 8, 30, 15));
      expect(deferred.createdAt, original.createdAt);
      expect(deferred.issueId, original.issueId);
      expect(deferred.reason, original.reason);
      expect(deferred.candidateSummary, original.candidateSummary);
      expect(deferred.targetSourceRecordId, original.targetSourceRecordId);
    });

    test('requires createdAt not later than updatedAt', () {
      expect(
        () => _item(
          createdAt: DateTime.utc(2026, 8, 30, 15),
          updatedAt: DateTime.utc(2026, 8, 30, 14),
        ),
        throwsArgumentError,
      );
      expect(
        () => _item().copyWith(updatedAt: DateTime.utc(2026, 8, 30, 11)),
        throwsArgumentError,
      );
    });
  });

  group('MergeReviewWorkItemCodec', () {
    test('unsupported envelopes fail open', () {
      final invalidPayloads = <String?>[
        null,
        '',
        '{',
        '[]',
        '{}',
        '{"schemaVersion":1.0,"items":[]}',
        '{"schemaVersion":2,"items":[]}',
        '{"schemaVersion":1,"items":{}}',
        '{"schemaVersion":1,"items":[],"extra":true}',
      ];

      for (final payload in invalidPayloads) {
        expect(
          MergeReviewWorkItemCodec.decode(payload),
          isEmpty,
          reason: 'payload: $payload',
        );
      }
    });

    test('filters invalid items while retaining valid ordered items', () {
      final valid = _item();
      final deferred = _item(
        identity: _identity(
          canonicalFoodId: 'canonical-2',
          sourceRecordId: '',
          subjectKey: 'nutrient:iron',
          type: MergeReviewIssueType.multiSourceNutrientVariance,
        ),
        targetSourceRecordId: 'actionable-source',
        status: MergeReviewWorkItemStatus.deferred,
      );
      final invalidItems = <Object?>[
        null,
        42,
        {'issueId': valid.issueId},
        {...valid.toJson(), 'status': 'completed'},
        {...valid.toJson(), 'type': 'futureType'},
        {...valid.toJson(), 'issueId': 'not-structured'},
        {...valid.toJson(), 'canonicalFoodId': 'identity-mismatch'},
        {...valid.toJson(), 'updatedAt': 'not-a-date'},
        {
          ...valid.toJson(),
          'createdAt': '2026-08-30T15:00:00.000Z',
          'updatedAt': '2026-08-30T14:00:00.000Z',
        },
        {...valid.toJson(), 'extra': true},
      ];
      final payload = jsonEncode({
        'schemaVersion': 1,
        'items': [valid.toJson(), ...invalidItems, deferred.toJson()],
      });

      expect(MergeReviewWorkItemCodec.decode(payload), [valid, deferred]);
    });

    test('rejects every missing item field', () {
      final valid = _item();
      for (final key in valid.toJson().keys) {
        final missing = Map<String, Object?>.from(valid.toJson())..remove(key);
        expect(
          MergeReviewWorkItem.tryFromJson(missing),
          isNull,
          reason: 'missing: $key',
        );
      }
    });

    test('round-trips nullable suggestion and both statuses', () {
      final queued = _item(suggestedCanonicalFoodId: null);
      final deferred = _item(
        identity: _identity(
          canonicalFoodId: 'canonical-2',
          sourceRecordId: 'source-2',
          subjectKey: 'audit:create',
          type: MergeReviewIssueType.createdWithCandidates,
        ),
        targetSourceRecordId: 'source-2',
        status: MergeReviewWorkItemStatus.deferred,
        suggestedCanonicalFoodId: 'canonical-3',
      );

      expect(
        MergeReviewWorkItemCodec.decode(
          MergeReviewWorkItemCodec.encode([queued, deferred]),
        ),
        [queued, deferred],
      );
    });

    test('freezes every persisted type and status token as a literal', () {
      const typeTokens = <MergeReviewIssueType, String>{
        MergeReviewIssueType.lowConfidenceReuse: 'lowConfidenceReuse',
        MergeReviewIssueType.categoryConflictCandidate:
            'categoryConflictCandidate',
        MergeReviewIssueType.createdWithCandidates: 'createdWithCandidates',
        MergeReviewIssueType.multiSourceNutrientVariance:
            'multiSourceNutrientVariance',
      };
      const statusTokens = <MergeReviewWorkItemStatus, String>{
        MergeReviewWorkItemStatus.queued: 'queued',
        MergeReviewWorkItemStatus.deferred: 'deferred',
      };

      for (final typeEntry in typeTokens.entries) {
        final isNutrientVariance =
            typeEntry.key == MergeReviewIssueType.multiSourceNutrientVariance;
        final identity = _identity(
          canonicalFoodId: 'canonical-${typeEntry.value}',
          sourceRecordId: isNutrientVariance ? '' : 'source-1',
          type: typeEntry.key,
          subjectKey: 'subject-${typeEntry.value}',
        );
        for (final statusEntry in statusTokens.entries) {
          final item = _item(identity: identity, status: statusEntry.key);
          final json = item.toJson();

          expect(json['type'], typeEntry.value);
          expect(json['status'], statusEntry.value);
          expect(MergeReviewWorkItem.tryFromJson(json)?.type, typeEntry.key);
          expect(
            MergeReviewWorkItem.tryFromJson(json)?.status,
            statusEntry.key,
          );
        }
      }
    });
  });
}

MergeReviewIssueIdentity _identity({
  String canonicalFoodId = 'canonical-1',
  String sourceRecordId = 'source-1',
  MergeReviewIssueType type = MergeReviewIssueType.categoryConflictCandidate,
  String subjectKey = 'candidate:canonical-2',
}) {
  return MergeReviewIssueIdentity(
    canonicalFoodId: canonicalFoodId,
    sourceRecordId: sourceRecordId,
    type: type,
    subjectKey: subjectKey,
  );
}

MergeReviewWorkItem _item({
  MergeReviewIssueIdentity? identity,
  String? canonicalFoodId,
  String? identitySourceRecordId,
  String targetSourceRecordId = 'source-1',
  MergeReviewIssueType? type,
  String? subjectKey,
  MergeReviewWorkItemStatus status = MergeReviewWorkItemStatus.queued,
  String? suggestedCanonicalFoodId = 'canonical-2',
  DateTime? issueCreatedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final resolvedIdentity = identity ?? _identity();
  return MergeReviewWorkItem(
    issueId: resolvedIdentity.encode(),
    canonicalFoodId: canonicalFoodId ?? resolvedIdentity.canonicalFoodId,
    identitySourceRecordId:
        identitySourceRecordId ?? resolvedIdentity.sourceRecordId,
    targetSourceRecordId: targetSourceRecordId,
    type: type ?? resolvedIdentity.type,
    subjectKey: subjectKey ?? resolvedIdentity.subjectKey,
    status: status,
    suggestedCanonicalFoodId: suggestedCanonicalFoodId,
    reason: 'Candidate category conflicts with canonical food.',
    candidateSummary: 'Candidate canonical-2',
    issueCreatedAt: issueCreatedAt ?? DateTime.utc(2026, 8, 30, 10),
    createdAt: createdAt ?? DateTime.utc(2026, 8, 30, 12),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 30, 12),
  );
}

MergeReviewIssue _issue({
  required MergeReviewIssueIdentity identity,
  String? id,
  String? canonicalFoodId,
  String sourceRecordId = 'source-1',
  MergeReviewIssueType? type,
  String? suggestedCanonicalFoodId = 'canonical-2',
  String reason = 'Candidate category conflicts with canonical food.',
  String candidateSummary = 'Candidate canonical-2',
  DateTime? createdAt,
}) {
  return MergeReviewIssue(
    id: id ?? identity.encode(),
    canonicalFoodId: canonicalFoodId ?? identity.canonicalFoodId,
    sourceRecordId: sourceRecordId,
    type: type ?? identity.type,
    severity: MergeReviewSeverity.warning,
    reason: reason,
    candidateSummary: candidateSummary,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 30, 10),
    suggestedCanonicalFoodId: suggestedCanonicalFoodId,
  );
}
