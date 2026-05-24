import 'dart:convert';

import 'package:http/http.dart' as http;

class OllamaClient {
  OllamaClient({
    http.Client? client,
    this.endpoint = 'http://127.0.0.1:11434',
    this.model = 'llama3',
    this.timeout = const Duration(seconds: 3),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;
  final String model;
  final Duration timeout;

  Future<String> generateJson({required String prompt}) async {
    final uri = Uri.parse('$endpoint/api/generate');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'stream': false,
            'format': 'json',
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw StateError(
        'Ollama request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['response'] ?? '{}').toString();
  }
}
