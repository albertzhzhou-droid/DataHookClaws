#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

import 'package:data_hook_claws/src/domain/normalization/nutrient_comparison_units.dart';

class _NormalizationCase {
  const _NormalizationCase({
    required this.label,
    required this.amount,
    required this.unit,
    required this.expectedNormalizedUnit,
    required this.expectedCanonical,
    required this.expectedDenominator,
    required this.expectedScale,
  });

  final String label;
  final double amount;
  final String unit;
  final String expectedNormalizedUnit;
  final String expectedCanonical;
  final String expectedDenominator;
  final double expectedScale;
}

class _NormalizationFailureCase {
  const _NormalizationFailureCase({required this.label, required this.unit});

  final String label;
  final String unit;
}

class _ComparabilityCase {
  const _ComparabilityCase({
    required this.label,
    required this.leftUnit,
    required this.rightUnit,
    required this.expectedComparable,
  });

  final String label;
  final String leftUnit;
  final String rightUnit;
  final bool expectedComparable;
}

void main() {
  final fixturePath =
      Platform.environment['DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE'] ??
      'tool/fixtures/compare_unit_normalization_cases.json';
  final fixture = _loadFixture(fixturePath);
  final cases = fixture.normalizationCases;
  final failureCases = fixture.failureCases;
  final comparabilityCases = fixture.comparabilityCases;

  var failed = 0;
  for (final sample in cases) {
    final normalized = normalizeNutrientComparisonUnit(sample.unit);
    if (normalized == null) {
      stdout.writeln(
        'FAILED ${sample.label}: unit "${sample.unit}" is not normalized',
      );
      failed++;
      continue;
    }

    if (_almostEqual(normalized.scaleToCanonical, sample.expectedScale) !=
        true) {
      stdout.writeln(
        'FAILED ${sample.label}: scale ${normalized.scaleToCanonical} != ${sample.expectedScale}',
      );
      failed++;
      continue;
    }

    if (normalized.canonicalUnit != sample.expectedCanonical) {
      stdout.writeln(
        'FAILED ${sample.label}: canonical ${normalized.canonicalUnit} != ${sample.expectedCanonical}',
      );
      failed++;
      continue;
    }

    final normalizedDenominator = normalized.denominator ?? '';
    if (normalizedDenominator != sample.expectedDenominator) {
      stdout.writeln(
        'FAILED ${sample.label}: denominator $normalizedDenominator != ${sample.expectedDenominator}',
      );
      failed++;
      continue;
    }

    final normalizedUnit = normalizedDenominator.isEmpty
        ? normalized.canonicalUnit
        : '${normalized.canonicalUnit}/$normalizedDenominator';

    if (normalizedUnit != sample.expectedNormalizedUnit) {
      stdout.writeln(
        'FAILED ${sample.label}: normalizedUnit $normalizedUnit != ${sample.expectedNormalizedUnit}',
      );
      failed++;
      continue;
    }

    final comparableAmount = sample.amount * normalized.scaleToCanonical;
    stdout.writeln(
      'PASS ${sample.label}: ${sample.unit} -> $normalizedUnit(${comparableAmount.toStringAsFixed(4)})',
    );
  }

  for (final sample in failureCases) {
    final normalized = normalizeNutrientComparisonUnit(sample.unit);
    if (normalized != null) {
      stdout.writeln(
        'FAILED ${sample.label}: unit "${sample.unit}" unexpectedly normalized to '
        '${normalized.displayUnit}',
      );
      failed++;
    } else {
      stdout.writeln(
        'PASS ${sample.label}: unit "${sample.unit}" is rejected as expected.',
      );
    }
  }

  for (final sample in comparabilityCases) {
    final left = normalizeNutrientComparisonUnit(sample.leftUnit);
    final right = normalizeNutrientComparisonUnit(sample.rightUnit);
    if (left == null) {
      stdout.writeln(
        'FAILED ${sample.label}: left unit "${sample.leftUnit}" failed normalization',
      );
      failed++;
      continue;
    }
    if (right == null) {
      stdout.writeln(
        'FAILED ${sample.label}: right unit "${sample.rightUnit}" failed normalization',
      );
      failed++;
      continue;
    }
    if (left.isComparableWith(right) != sample.expectedComparable) {
      stdout.writeln(
        'FAILED ${sample.label}: comparability mismatch (${sample.leftUnit} -> '
        '${left.displayUnit}, ${sample.rightUnit} -> ${right.displayUnit}, '
        'expected=${sample.expectedComparable})',
      );
      failed++;
      continue;
    }
    stdout.writeln(
      'PASS ${sample.label}: ${sample.leftUnit} and ${sample.rightUnit} '
      'comparability=${left.isComparableWith(right)}',
    );
  }

  if (failed > 0) {
    stderr.writeln('compare unit smoke check failed: $failed case(s)');
    throw StateError('compare unit smoke check failed');
  }

  stdout.writeln('compare unit smoke check passed.');
}

bool _almostEqual(double left, double right) {
  return (left - right).abs() <= 1e-9;
}

class _NormalizationFixture {
  const _NormalizationFixture({
    required this.normalizationCases,
    required this.failureCases,
    required this.comparabilityCases,
  });

  final List<_NormalizationCase> normalizationCases;
  final List<_NormalizationFailureCase> failureCases;
  final List<_ComparabilityCase> comparabilityCases;
}

_NormalizationFixture _loadFixture(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      'Normalization fixture not found: $path, using in-file defaults.',
    );
    return _defaultFixture();
  }

  Object? raw;
  try {
    raw = jsonDecode(file.readAsStringSync());
  } catch (error) {
    stderr.writeln(
      'Failed to parse normalization fixture at $path: $error, using in-file defaults.',
    );
    return _defaultFixture();
  }
  if (raw is! Map<String, Object?>) {
    stderr.writeln(
      'Normalization fixture format invalid at $path, using in-file defaults.',
    );
    return _defaultFixture();
  }

  try {
    final normalizationCases = _coerceNormalizationCases(
      raw['normalizationCases'],
    );
    final failureCases = _coerceFailureCases(raw['failureCases']);
    final comparabilityCases = _coerceComparabilityCases(
      raw['comparabilityCases'],
    );
    if (normalizationCases.isEmpty &&
        failureCases.isEmpty &&
        comparabilityCases.isEmpty) {
      throw StateError('Normalization fixture contains no test cases.');
    }
    return _NormalizationFixture(
      normalizationCases: normalizationCases,
      failureCases: failureCases,
      comparabilityCases: comparabilityCases,
    );
  } catch (error) {
    stderr.writeln(
      'Failed to parse normalization fixture at $path: $error, using in-file defaults.',
    );
    return _defaultFixture();
  }
}

_NormalizationFixture _defaultFixture() => _NormalizationFixture(
  normalizationCases: const <_NormalizationCase>[
    _NormalizationCase(
      label: 'mg_to_g',
      amount: 1500,
      unit: 'mg',
      expectedNormalizedUnit: 'g',
      expectedCanonical: 'g',
      expectedDenominator: '',
      expectedScale: 0.001,
    ),
    _NormalizationCase(
      label: 'kcal_to_kcal',
      amount: 1000,
      unit: 'kcal',
      expectedNormalizedUnit: 'kcal',
      expectedCanonical: 'kcal',
      expectedDenominator: '',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'cal_to_kcal',
      amount: 1000000,
      unit: 'cal',
      expectedNormalizedUnit: 'kcal',
      expectedCanonical: 'kcal',
      expectedDenominator: '',
      expectedScale: 0.001,
    ),
    _NormalizationCase(
      label: 'kcalory_to_kcal',
      amount: 1000,
      unit: 'KILOCALORIES',
      expectedNormalizedUnit: 'kcal',
      expectedCanonical: 'kcal',
      expectedDenominator: '',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'percent_basic',
      amount: 10,
      unit: 'percent',
      expectedNormalizedUnit: '%',
      expectedCanonical: '%',
      expectedDenominator: '',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'kj_to_kcal',
      amount: 4184,
      unit: 'kJ',
      expectedNormalizedUnit: 'kcal',
      expectedCanonical: 'kcal',
      expectedDenominator: '',
      expectedScale: 0.2390057361,
    ),
    _NormalizationCase(
      label: 'kjoule_to_kcal',
      amount: 4.184,
      unit: 'kJoule',
      expectedNormalizedUnit: 'kcal',
      expectedCanonical: 'kcal',
      expectedDenominator: '',
      expectedScale: 0.2390057361,
    ),
    _NormalizationCase(
      label: 'g_per_100g',
      amount: 5,
      unit: 'g/100g',
      expectedNormalizedUnit: 'g/100g',
      expectedCanonical: 'g',
      expectedDenominator: '100g',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'g_per_serving',
      amount: 12.5,
      unit: 'g/Serving',
      expectedNormalizedUnit: 'g/serving',
      expectedCanonical: 'g',
      expectedDenominator: 'serving',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'iu_upper',
      amount: 100,
      unit: 'IU',
      expectedNormalizedUnit: 'IU',
      expectedCanonical: 'IU',
      expectedDenominator: '',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'mcg_to_g',
      amount: 2500,
      unit: 'mcg',
      expectedNormalizedUnit: 'g',
      expectedCanonical: 'g',
      expectedDenominator: '',
      expectedScale: 0.000001,
    ),
    _NormalizationCase(
      label: 'denominator_conflict_g_per_100g',
      amount: 100,
      unit: 'g/100g',
      expectedNormalizedUnit: 'g/100g',
      expectedCanonical: 'g',
      expectedDenominator: '100g',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'iu_plain',
      amount: 100,
      unit: 'IU',
      expectedNormalizedUnit: 'IU',
      expectedCanonical: 'IU',
      expectedDenominator: '',
      expectedScale: 1,
    ),
    _NormalizationCase(
      label: 'jittery_spaces_denominator',
      amount: 5,
      unit: 'g /( 100 g )',
      expectedNormalizedUnit: 'g/100g',
      expectedCanonical: 'g',
      expectedDenominator: '100g',
      expectedScale: 1,
    ),
  ],
  failureCases: const <_NormalizationFailureCase>[
    _NormalizationFailureCase(label: 'empty_unit', unit: ''),
    _NormalizationFailureCase(label: 'unknown_unit', unit: 'mystery-unit'),
    _NormalizationFailureCase(label: 'micro_curie_unit', unit: 'μCi'),
  ],
  comparabilityCases: const <_ComparabilityCase>[
    _ComparabilityCase(
      label: 'mg_and_g_are_comparable',
      leftUnit: 'mg',
      rightUnit: 'g',
      expectedComparable: true,
    ),
    _ComparabilityCase(
      label: 'kcal_and_cal_are_comparable',
      leftUnit: 'kcal',
      rightUnit: 'cal',
      expectedComparable: true,
    ),
    _ComparabilityCase(
      label: 'kj_and_kcal_are_comparable',
      leftUnit: 'kJ',
      rightUnit: 'kcal',
      expectedComparable: true,
    ),
    _ComparabilityCase(
      label: 'percent_and_percent_are_comparable',
      leftUnit: 'percent',
      rightUnit: '%',
      expectedComparable: true,
    ),
    _ComparabilityCase(
      label: 'denominator_must_match_for_mass',
      leftUnit: 'g',
      rightUnit: 'g/100g',
      expectedComparable: false,
    ),
  ],
);

List<_NormalizationCase> _coerceNormalizationCases(Object? rawValue) {
  return _fixtureEntries(rawValue, 'normalizationCases')
      .map((entry) {
        final expectedScale = entry['expectedScale'];
        final expectedCanonical = entry['expectedCanonical'];
        final expectedDenominator = entry['expectedDenominator'];
        final expectedNormalizedUnit = entry['expectedNormalizedUnit'];
        if (entry['label'] is! String ||
            entry['amount'] is! num ||
            entry['unit'] is! String ||
            expectedCanonical is! String ||
            expectedDenominator is! String ||
            expectedNormalizedUnit is! String ||
            expectedScale is! num) {
          throw StateError('Invalid normalization case: $entry');
        }
        return _NormalizationCase(
          label: entry['label']! as String,
          amount: (entry['amount'] as num).toDouble(),
          unit: entry['unit']! as String,
          expectedNormalizedUnit: expectedNormalizedUnit,
          expectedCanonical: expectedCanonical,
          expectedDenominator: expectedDenominator,
          expectedScale: expectedScale.toDouble(),
        );
      })
      .toList(growable: false);
}

List<_NormalizationFailureCase> _coerceFailureCases(Object? rawValue) {
  return _fixtureEntries(rawValue, 'failureCases')
      .map((entry) {
        if (entry['label'] is! String || entry['unit'] is! String) {
          throw StateError('Invalid failure case: $entry');
        }
        return _NormalizationFailureCase(
          label: entry['label']! as String,
          unit: entry['unit']! as String,
        );
      })
      .toList(growable: false);
}

List<_ComparabilityCase> _coerceComparabilityCases(Object? rawValue) {
  return _fixtureEntries(rawValue, 'comparabilityCases')
      .map((entry) {
        if (entry['label'] is! String ||
            entry['leftUnit'] is! String ||
            entry['rightUnit'] is! String ||
            entry['expectedComparable'] is! bool) {
          throw StateError('Invalid comparability case: $entry');
        }
        return _ComparabilityCase(
          label: entry['label']! as String,
          leftUnit: entry['leftUnit']! as String,
          rightUnit: entry['rightUnit']! as String,
          expectedComparable: entry['expectedComparable']! as bool,
        );
      })
      .toList(growable: false);
}

List<Map<String, Object?>> _fixtureEntries(Object? rawValue, String fieldName) {
  if (rawValue is! List<Object?>) {
    throw StateError('$fieldName must be a JSON array.');
  }

  final entries = <Map<String, Object?>>[];
  for (var index = 0; index < rawValue.length; index++) {
    final entry = rawValue[index];
    if (entry is! Map<String, Object?>) {
      throw StateError('$fieldName[$index] must be a JSON object.');
    }
    entries.add(entry);
  }
  return entries;
}
