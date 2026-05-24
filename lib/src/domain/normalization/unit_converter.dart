import 'text_normalizer.dart';

class UnitConverter {
  const UnitConverter();

  String normalizeUnit(String rawUnit, TextNormalizer textNormalizer) {
    final unit = textNormalizer.cleanText(rawUnit).toLowerCase();
    if (unit.contains('kcal')) {
      return 'kcal';
    }
    if (unit.contains('kj')) {
      return 'kJ';
    }
    if (unit.contains('μg') || unit.contains('ug')) {
      return 'μg';
    }
    if (unit == 'mg') {
      return 'mg';
    }
    if (unit == 'g' || unit.contains(' g')) {
      return 'g';
    }
    if (unit == '%') {
      return '%';
    }
    return textNormalizer.cleanText(rawUnit);
  }

  double? convert({
    required double amount,
    required String fromUnit,
    required String toUnit,
  }) {
    if (fromUnit == toUnit || fromUnit.isEmpty || toUnit.isEmpty) {
      return amount;
    }
    if (fromUnit == 'mg' && toUnit == 'μg') {
      return amount * 1000;
    }
    if (fromUnit == 'μg' && toUnit == 'mg') {
      return amount / 1000;
    }
    if (fromUnit == 'g' && toUnit == 'mg') {
      return amount * 1000;
    }
    if (fromUnit == 'mg' && toUnit == 'g') {
      return amount / 1000;
    }
    return amount;
  }
}
