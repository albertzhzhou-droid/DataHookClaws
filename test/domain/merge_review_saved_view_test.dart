import 'dart:convert';

import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_saved_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewSavedView', () {
    test('normalizes names and timestamps at the model boundary', () {
      final view = MergeReviewSavedView(
        id: '  view-1  ',
        name: '  High\n   confidence\tissues  ',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
        createdAt: DateTime.parse('2026-08-30T09:00:00-04:00'),
        updatedAt: DateTime.parse('2026-08-30T10:00:00-04:00'),
      );

      expect(view.id, 'view-1');
      expect(view.name, 'High confidence issues');
      expect(view.normalizedName, 'high confidence issues');
      expect(view.createdAt.isUtc, isTrue);
      expect(view.updatedAt.isUtc, isTrue);
      expect(view.toJson()['createdAt'], '2026-08-30T13:00:00.000Z');
      expect(view.toJson()['updatedAt'], '2026-08-30T14:00:00.000Z');
    });

    test('rejects empty and overlong normalized names', () {
      expect(() => _view(name: ' \n\t '), throwsArgumentError);
      expect(
        () => _view(name: List.filled(81, 'x').join()),
        throwsArgumentError,
      );
      expect(
        _view(name: List.filled(80, 'x').join()).name.length,
        MergeReviewSavedView.maxNameLength,
      );
    });

    test('requires createdAt not later than updatedAt', () {
      expect(
        () => _view(
          createdAt: DateTime.utc(2026, 8, 30, 15),
          updatedAt: DateTime.utc(2026, 8, 30, 14),
        ),
        throwsArgumentError,
      );
    });
  });

  group('MergeReviewSavedViewCodec', () {
    test('round-trips every severity and issue-type combination', () {
      final severities = <MergeReviewSeverity?>[
        null,
        ...MergeReviewSeverity.values,
      ];
      final types = <MergeReviewIssueType?>[
        null,
        ...MergeReviewIssueType.values,
      ];
      final views = <MergeReviewSavedView>[];
      var index = 0;
      for (final severity in severities) {
        for (final type in types) {
          views.add(
            _view(
              id: 'view-$index',
              name: 'View $index',
              filter: MergeReviewFilter(severity: severity, type: type),
              updatedAt: DateTime.utc(2026, 8, 30, 12, index),
            ),
          );
          index += 1;
        }
      }

      final payload = MergeReviewSavedViewCodec.encode(views);

      expect(jsonDecode(payload), isA<Map<String, dynamic>>());
      expect(MergeReviewSavedViewCodec.decode(payload), views);
      expect(
        MergeReviewSavedViewCodec.encode(const []),
        MergeReviewSavedViewCodec.emptyPayload,
      );
    });

    test('unsupported roots and schemas fail open', () {
      final invalidPayloads = <String?>[
        null,
        '',
        '{',
        '[]',
        '{}',
        '{"schemaVersion":1.0,"views":[]}',
        '{"schemaVersion":2,"views":[]}',
        '{"schemaVersion":1,"views":{}}',
      ];

      for (final payload in invalidPayloads) {
        expect(
          MergeReviewSavedViewCodec.decode(payload),
          isEmpty,
          reason: 'payload: $payload',
        );
      }
    });

    test('rejects unknown root keys instead of silently accepting them', () {
      final valid = _view(name: 'Warnings');
      final payload = jsonEncode({
        'schemaVersion': 1,
        'views': [valid.toJson()],
        'futureField': true,
      });

      expect(MergeReviewSavedViewCodec.decode(payload), isEmpty);
    });

    test('rejects unknown saved-view item keys instead of accepting them', () {
      final valid = _view(name: 'Warnings');
      final withFutureField = {...valid.toJson(), 'futureField': true};

      expect(MergeReviewSavedView.tryFromJson(withFutureField), isNull);
      expect(
        MergeReviewSavedViewCodec.decode(
          jsonEncode({
            'schemaVersion': 1,
            'views': [withFutureField],
          }),
        ),
        isEmpty,
      );
    });

    test('skips bad entries without converting invalid filters to All', () {
      final valid = _view(
        id: 'valid',
        name: 'Warnings',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      final payload = jsonEncode({
        'schemaVersion': 1,
        'views': [
          null,
          {'id': 'missing-fields'},
          {
            ...valid.toJson(),
            'id': 'unknown-filter',
            'filter': {'schemaVersion': 1, 'severity': 'futureSeverity'},
          },
          {...valid.toJson(), 'id': 'bad-date', 'updatedAt': 'not-a-date'},
          valid.toJson(),
        ],
      });

      final decoded = MergeReviewSavedViewCodec.decode(payload);

      expect(decoded, [valid]);
      expect(() => decoded.add(valid), throwsUnsupportedError);
    });
  });
}

MergeReviewSavedView _view({
  String id = 'view-1',
  String name = 'Saved view',
  MergeReviewFilter filter = MergeReviewFilter.all,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return MergeReviewSavedView(
    id: id,
    name: name,
    filter: filter,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 30, 12),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 30, 12),
  );
}
