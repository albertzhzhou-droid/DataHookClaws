import 'dart:async';

import 'package:data_hook_claws/src/domain/model_budget_controller.dart';
import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/query_expansion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows calls within rate limit and denies after limit', () {
    final controller = ModelBudgetController(maxCallsPerMinute: 1);

    expect(controller.evaluate('salmon').allowed, isTrue);
    controller.recordCall();
    expect(controller.evaluate('salmon').allowed, isFalse);
  });

  test('query expansion falls back and logs when budget denies', () async {
    final logs = <String>[];
    final service = QueryExpansionService(
      modelBudgetController: ModelBudgetController(maxCallsPerMinute: 0),
      ollamaClient: _CountingOllamaClient(),
      persistSuggestion: (entry) async => logs.add(entry.suggestionType),
    );

    final result = await service.expand('salmon');

    expect(result.usedModel, isFalse);
    expect(logs, ['query-expansion-fallback']);
  });

  test('query expansion falls back on endpoint failure', () async {
    final logs = <String>[];
    final service = QueryExpansionService(
      ollamaClient: _CountingOllamaClient(error: TimeoutException('timeout')),
      persistSuggestion: (entry) async => logs.add(entry.suggestionType),
    );

    final result = await service.expand('salmon');

    expect(result.usedModel, isFalse);
    expect(logs, ['query-expansion-fallback']);
  });
}

class _CountingOllamaClient extends OllamaClient {
  _CountingOllamaClient({this.error}) : super();

  final Object? error;

  @override
  Future<String> generateJson({required String prompt}) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return '{"aliases":["fish"],"translations":["salmon"],"sourceHints":[]}';
  }
}
