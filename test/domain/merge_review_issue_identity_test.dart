import 'dart:convert';

import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewIssueIdentity', () {
    test('round-trips Unicode and delimiter-like field content', () {
      final identity = MergeReviewIssueIdentity(
        canonicalFoodId: 'canonical:食物/🍎|A',
        sourceRecordId: 'source::café/?=42',
        type: MergeReviewIssueType.multiSourceNutrientVariance,
        subjectKey: 'nutrient:维生素 C|mg/100 g?source=A:B',
      );

      final encoded = identity.encode();
      final payload = encoded.substring(
        MergeReviewIssueIdentity.encodedPrefix.length,
      );

      expect(encoded, startsWith(MergeReviewIssueIdentity.encodedPrefix));
      expect(payload, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(payload, isNot(contains('=')));
      expect(MergeReviewIssueIdentity.tryDecode(encoded), identity);
      expect(
        MergeReviewIssueIdentity.tryDecode(encoded).hashCode,
        identity.hashCode,
      );
    });

    test('normalizes boundaries and permits an empty source id', () {
      final normalized = MergeReviewIssueIdentity(
        canonicalFoodId: '  canonical-1 ',
        sourceRecordId: '   ',
        type: MergeReviewIssueType.createdWithCandidates,
        subjectKey: '  audit:create  ',
      );

      expect(normalized.canonicalFoodId, 'canonical-1');
      expect(normalized.sourceRecordId, isEmpty);
      expect(normalized.subjectKey, 'audit:create');
      expect(
        MergeReviewIssueIdentity.tryDecode(normalized.encode()),
        normalized,
      );
    });

    test('rejects empty required fields at construction', () {
      expect(
        () => MergeReviewIssueIdentity(
          canonicalFoodId: ' \n ',
          sourceRecordId: '',
          type: MergeReviewIssueType.lowConfidenceReuse,
          subjectKey: 'audit',
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewIssueIdentity(
          canonicalFoodId: 'canonical-1',
          sourceRecordId: '',
          type: MergeReviewIssueType.lowConfidenceReuse,
          subjectKey: '\t',
        ),
        throwsArgumentError,
      );
    });

    test('encoding is deterministic for equivalent normalized fields', () {
      final first = MergeReviewIssueIdentity(
        canonicalFoodId: ' canonical-1 ',
        sourceRecordId: ' source-1 ',
        type: MergeReviewIssueType.categoryConflictCandidate,
        subjectKey: ' candidate:canonical-2 ',
      );
      final second = MergeReviewIssueIdentity(
        canonicalFoodId: 'canonical-1',
        sourceRecordId: 'source-1',
        type: MergeReviewIssueType.categoryConflictCandidate,
        subjectKey: 'candidate:canonical-2',
      );

      expect(first, second);
      expect(first.encode(), second.encode());
      expect(first.encode(), first.encode());
    });

    test('every identity field contributes to equality and encoding', () {
      final identities = [
        _identity(),
        _identity(canonicalFoodId: 'canonical-2'),
        _identity(sourceRecordId: 'source-2'),
        _identity(type: MergeReviewIssueType.createdWithCandidates),
        _identity(subjectKey: 'candidate:canonical-3'),
      ];

      expect(identities.toSet(), hasLength(identities.length));
      expect(
        identities.map((identity) => identity.encode()).toSet(),
        hasLength(identities.length),
      );
    });

    test('strict decoder rejects bad prefix, base64, UTF-8, and JSON', () {
      final invalidValues = <String?>[
        null,
        '',
        'merge-review:',
        MergeReviewIssueIdentity.encodedPrefix,
        '${MergeReviewIssueIdentity.encodedPrefix}%',
        '${MergeReviewIssueIdentity.encodedPrefix}a',
        _encodeBytes(utf8.encode('not JSON')),
        _encodeBytes([0xff]),
        _encodeRawJson(const []),
        '${_identity().encode()}=',
      ];

      for (final value in invalidValues) {
        expect(
          MergeReviewIssueIdentity.tryDecode(value),
          isNull,
          reason: 'value: $value',
        );
      }
    });

    test('strict decoder rejects unknown versions, enums, and field types', () {
      final invalidPayloads = <Map<String, Object?>>[
        {..._validJson(), 'schemaVersion': 2},
        {..._validJson(), 'schemaVersion': 1.0},
        {..._validJson(), 'type': 'futureIssueType'},
        {..._validJson(), 'type': 42},
        {..._validJson(), 'canonicalFoodId': 42},
        {..._validJson(), 'sourceRecordId': null},
        {..._validJson(), 'subjectKey': false},
        {..._validJson(), 'canonicalFoodId': ''},
        {..._validJson(), 'canonicalFoodId': '   '},
        {..._validJson(), 'subjectKey': ''},
        {..._validJson(), 'subjectKey': '\n'},
      ];

      for (final payload in invalidPayloads) {
        expect(
          MergeReviewIssueIdentity.tryDecode(_encodeRawJson(payload)),
          isNull,
          reason: 'payload: $payload',
        );
      }
    });

    test('strict decoder rejects every missing field and any extra field', () {
      for (final key in _validJson().keys) {
        final missing = Map<String, Object?>.from(_validJson())..remove(key);
        expect(
          MergeReviewIssueIdentity.tryDecode(_encodeRawJson(missing)),
          isNull,
          reason: 'missing: $key',
        );
      }

      expect(
        MergeReviewIssueIdentity.tryDecode(
          _encodeRawJson({..._validJson(), 'futureField': 'value'}),
        ),
        isNull,
      );
    });

    test('strict decoder accepts every known issue type', () {
      for (final type in MergeReviewIssueType.values) {
        final identity = _identity(type: type);
        expect(
          MergeReviewIssueIdentity.tryDecode(identity.encode()),
          identity,
          reason: 'type: ${type.name}',
        );
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

Map<String, Object?> _validJson() {
  return Map<String, Object?>.from(_identity().toJson());
}

String _encodeRawJson(Object? value) {
  return _encodeBytes(utf8.encode(jsonEncode(value)));
}

String _encodeBytes(List<int> bytes) {
  final payload = base64Url.encode(bytes).replaceAll('=', '');
  return '${MergeReviewIssueIdentity.encodedPrefix}$payload';
}
