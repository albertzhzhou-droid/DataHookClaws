import 'dart:convert';

import 'package:http/http.dart' as http;

class UsdaApiClient {
  UsdaApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint = 'api.nal.usda.gov';

  final http.Client _client;

  Future<List<Map<String, dynamic>>> searchFoods({
    required String apiKey,
    required String query,
    required int limit,
  }) async {
    final uri = Uri.https(_endpoint, '/fdc/v1/foods/search', {
      'api_key': apiKey,
      'query': query,
      'pageSize': '${limit.clamp(1, 50)}',
      'dataType': 'Foundation,SR Legacy',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'USDA request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['foods'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }
}
