import 'dart:async';

import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/query_expansion_service.dart';
import 'package:data_hook_claws/src/models/ai_suggestion_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns structured expansions from ollama response', () async {
    final logs = <AiSuggestionLogEntry>[];
    final service = QueryExpansionService(
      persistSuggestion: (entry) async => logs.add(entry),
      ollamaClient: _FakeOllamaClient(
        response:
            '{"aliases":["Atlantic salmon"],"translations":["三文鱼","サーモン"],"sourceHints":["usda","canada-cnf"]}',
      ),
    );

    final result = await service.expand('salmon');

    expect(result.aliases, contains('Atlantic salmon'));
    expect(result.translations, contains('三文鱼'));
    expect(result.sourceHints, contains('usda'));
    expect(result.usedModel, isTrue);
    expect(logs, hasLength(1));
  });

  test('falls back when ollama times out', () async {
    final logs = <AiSuggestionLogEntry>[];
    final service = QueryExpansionService(
      persistSuggestion: (entry) async => logs.add(entry),
      ollamaClient: _FakeOllamaClient(error: TimeoutException('timeout')),
    );

    final result = await service.expand('vitamin-c');

    expect(result.usedModel, isFalse);
    expect(result.aliases, contains('vitamin c'));
    expect(logs.single.suggestionType, 'query-expansion-fallback');
  });

  test('falls back when ollama endpoint fails', () async {
    final service = QueryExpansionService(
      persistSuggestion: (_) async {},
      ollamaClient: _FakeOllamaClient(error: StateError('boom')),
    );

    final result = await service.expand('tofu');
    expect(result.usedModel, isFalse);
    expect(result.primaryQuery, 'tofu');
  });
}

class _FakeOllamaClient extends OllamaClient {
  _FakeOllamaClient({this.response = '{}', this.error}) : super();

  final String response;
  final Object? error;

  @override
  Future<String> generateJson({required String prompt}) async {
    if (error != null) {
      throw error!;
    }
    return response;
  }
}
