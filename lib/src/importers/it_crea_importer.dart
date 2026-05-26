import 'package:http/http.dart' as http;

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';

class ItCreaImporter implements FoodImporter {
  ItCreaImporter({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _indexUri = Uri.parse(
    'https://www.alimentinutrizione.it/tabelle-nutrizionali/ricerca-per-alimento',
  );

  final http.Client _client;

  @override
  String get id => 'it-crea';

  @override
  String get displayName => 'CREA Food Composition Tables';

  @override
  String get country => 'Italy';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final indexResponse = await _client.get(_indexUri);
    if (indexResponse.statusCode != 200) {
      throw StateError(
        'Italy CREA index request failed with status ${indexResponse.statusCode}.',
      );
    }

    final normalizedQuery = _normalizeText(request.query);
    final entries = _parseIndexEntries(indexResponse.body)
        .where(
          (entry) =>
              normalizedQuery.isEmpty ||
              _normalizeText(entry.name).contains(normalizedQuery),
        )
        .take(request.limit)
        .toList(growable: false);

    final foods = <RawFoodRecord>[];
    for (final entry in entries) {
      final detailResponse = await _client.get(entry.uri);
      if (detailResponse.statusCode != 200) {
        throw StateError(
          'Italy CREA detail request failed for ${entry.code} with status ${detailResponse.statusCode}.',
        );
      }
      foods.add(_parseFood(entry, detailResponse.body));
    }

    return foods;
  }

  List<_IndexEntry> _parseIndexEntries(String html) {
    final matches = RegExp(
      r'<a[^>]+href="([^"]*/tabelle-nutrizionali/(\d+))"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    final seenCodes = <String>{};
    final entries = <_IndexEntry>[];

    for (final match in matches) {
      final href = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      final name = _stripHtml(match.group(3) ?? '');
      if (href.isEmpty || code.isEmpty || name.isEmpty || !seenCodes.add(code)) {
        continue;
      }
      entries.add(
        _IndexEntry(
          code: code,
          name: name,
          uri: _indexUri.resolve(href),
        ),
      );
    }

    return entries;
  }

  RawFoodRecord _parseFood(_IndexEntry entry, String html) {
    final text = _flattenHtml(html);
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final name = _fieldValue(lines, 'Nome alimento') ??
        _fieldValue(lines, 'Food name') ??
        entry.name;
    final category = _fieldValue(lines, 'Categoria') ?? 'Official food';
    final englishName = _fieldValue(lines, 'English Name') ?? '';
    final ediblePortion = _fieldValue(lines, 'Parte Edibile') ?? '';
    final portion = _fieldValue(lines, 'Porzione') ?? '';
    final nutrients = _extractNutrients(lines);
    if (nutrients.isEmpty) {
      throw StateError(
        'Italy CREA detail page for ${entry.code} did not contain any nutrient rows.',
      );
    }

    final descriptionParts = <String>[
      'Imported live from the official CREA Alimenti e Nutrizione portal.',
      if (englishName.isNotEmpty) 'English name: $englishName',
      if (ediblePortion.isNotEmpty) 'Edible portion: $ediblePortion',
      'Source code: ${entry.code}',
    ];

    return RawFoodRecord(
      sourceRecordId: entry.code,
      name: name,
      category: category,
      country: country,
      sourceName: displayName,
      description: descriptionParts.join(' '),
      servingBasis: portion.isEmpty
          ? 'Per 100 g edible portion'
          : 'Per 100 g edible portion; portion $portion',
      tags: const ['official', 'italy', 'crea', 'web import'],
      nutrients: nutrients,
      lastUpdated: DateTime(2019, 12, 1),
    );
  }

  List<RawNutrientRecord> _extractNutrients(List<String> lines) {
    final nutrients = <RawNutrientRecord>[];
    var inNutrientBlock = false;

    for (final line in lines) {
      if (line.startsWith('Ultimo aggiornamento')) {
        break;
      }
      if (_isNutrientSectionHeading(line)) {
        inNutrientBlock = true;
        continue;
      }
      if (!inNutrientBlock) {
        continue;
      }
      if (_isHeaderRow(line)) {
        continue;
      }

      final cells = line
          .split('\t')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList(growable: false);
      if (cells.length < 3) {
        continue;
      }

      final amount = _parseAmount(cells[2]);
      if (amount == null) {
        continue;
      }

      final label = _normalizeLabel(cells[0]);
      nutrients.add(
        RawNutrientRecord(
          label: label,
          amount: amount,
          unit: _normalizeUnit(cells[1]),
        ),
      );
    }

    return nutrients;
  }

  bool _isNutrientSectionHeading(String line) {
    const headings = {
      'MACRO NUTRIENTI',
      'MINERALI',
      'VITAMINE',
      'ALTRI COMPONENTI',
      'LIPIDI',
      'AMMINOACIDI',
    };
    return headings.contains(line.toUpperCase());
  }

  bool _isHeaderRow(String line) {
    final normalized = line.toLowerCase();
    return normalized.contains('descrizione nutriente') ||
        normalized.contains('valore per') ||
        normalized.contains('origine dato') ||
        normalized.contains('unità di misura');
  }

  String? _fieldValue(List<String> lines, String prefix) {
    for (final line in lines) {
      if (!line.startsWith(prefix)) {
        continue;
      }
      final value = line.substring(prefix.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _normalizeLabel(String rawLabel) {
    final label = rawLabel.trim().toLowerCase();
    if (label.startsWith('acqua')) {
      return 'Water';
    }
    if (label.startsWith('energia (kcal)')) {
      return 'Energy';
    }
    if (label.startsWith('energia (kj)')) {
      return 'Energy';
    }
    if (label.startsWith('proteine')) {
      return 'Protein';
    }
    if (label.startsWith('lipidi')) {
      return 'Fat';
    }
    if (label.startsWith('grassi saturi')) {
      return 'Saturated fat';
    }
    if (label.startsWith('carboidrati disponibili')) {
      return 'Carbohydrate';
    }
    if (label.startsWith('amido')) {
      return 'Starch';
    }
    if (label.startsWith('zuccheri')) {
      return 'Sugars';
    }
    if (label.startsWith('alcool')) {
      return 'Alcohol';
    }
    if (label.startsWith('fibra')) {
      return 'Fiber';
    }
    if (label.startsWith('sodio')) {
      return 'Sodium';
    }
    if (label.startsWith('potassio')) {
      return 'Potassium';
    }
    if (label.startsWith('calcio')) {
      return 'Calcium';
    }
    if (label.startsWith('fosforo')) {
      return 'Phosphorus';
    }
    if (label.startsWith('magnesio')) {
      return 'Magnesium';
    }
    if (label.startsWith('ferro')) {
      return 'Iron';
    }
    if (label.startsWith('zinco')) {
      return 'Zinc';
    }
    if (label.startsWith('rame')) {
      return 'Copper';
    }
    if (label.startsWith('tiamina')) {
      return 'Vitamin B1';
    }
    if (label.startsWith('riboflavina')) {
      return 'Vitamin B2';
    }
    if (label.startsWith('niacina')) {
      return 'Niacin';
    }
    if (label.startsWith('vitamina c')) {
      return 'Vitamin C';
    }
    if (label.startsWith('vitamina a')) {
      return 'Vitamin A';
    }
    return rawLabel.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  String _normalizeUnit(String rawUnit) {
    final match = RegExp(r'^([^\s(]+)').firstMatch(rawUnit.trim());
    return match == null ? rawUnit.trim() : match.group(1)!;
  }

  double? _parseAmount(String rawValue) {
    var normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'tr') {
      return 0;
    }
    normalized = normalized.replaceAll(' ', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  String _flattenHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</(tr|h1|h2|h3|p|li|div)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(td|th)>', caseSensitive: false), '\t')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&egrave;', 'e')
        .replaceAll('&igrave;', 'i')
        .replaceAll('&agrave;', 'a')
        .replaceAll('&ograve;', 'o')
        .replaceAll('&ugrave;', 'u')
        .replaceAll(RegExp(r' *\t *'), '\t')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'\t+'), '\t')
        .replaceAll(RegExp(r'\n+'), '\n')
        .trim();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _IndexEntry {
  const _IndexEntry({
    required this.code,
    required this.name,
    required this.uri,
  });

  final String code;
  final String name;
  final Uri uri;
}
