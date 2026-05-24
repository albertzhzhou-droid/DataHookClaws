class CanonicalNutrient {
  const CanonicalNutrient({required this.label, required this.unit});

  final String label;
  final String unit;
}

class NutrientDictionary {
  const NutrientDictionary();

  static const aliases = <String, CanonicalNutrient>{
    'energy': CanonicalNutrient(label: 'Energy', unit: 'kcal'),
    'energykcal': CanonicalNutrient(label: 'Energy', unit: 'kcal'),
    'protein': CanonicalNutrient(label: 'Protein', unit: 'g'),
    'fat': CanonicalNutrient(label: 'Fat', unit: 'g'),
    'carbohydrate': CanonicalNutrient(label: 'Carbohydrate', unit: 'g'),
    'fiber': CanonicalNutrient(label: 'Fiber', unit: 'g'),
    'water': CanonicalNutrient(label: 'Water', unit: 'g'),
    'sodium': CanonicalNutrient(label: 'Sodium', unit: 'mg'),
    'potassium': CanonicalNutrient(label: 'Potassium', unit: 'mg'),
    'calcium': CanonicalNutrient(label: 'Calcium', unit: 'mg'),
    'magnesium': CanonicalNutrient(label: 'Magnesium', unit: 'mg'),
    'phosphorus': CanonicalNutrient(label: 'Phosphorus', unit: 'mg'),
    'iron': CanonicalNutrient(label: 'Iron', unit: 'mg'),
    'zinc': CanonicalNutrient(label: 'Zinc', unit: 'mg'),
    'copper': CanonicalNutrient(label: 'Copper', unit: 'mg'),
    'manganese': CanonicalNutrient(label: 'Manganese', unit: 'mg'),
    'selenium': CanonicalNutrient(label: 'Selenium', unit: 'μg'),
    'iodine': CanonicalNutrient(label: 'Iodine', unit: 'μg'),
    'vitamina': CanonicalNutrient(label: 'Vitamin A', unit: 'μg'),
    'vitamind': CanonicalNutrient(label: 'Vitamin D', unit: 'μg'),
    'vitamine': CanonicalNutrient(label: 'Vitamin E', unit: 'mg'),
    'vitamink1': CanonicalNutrient(label: 'Vitamin K', unit: 'μg'),
    'vitamink': CanonicalNutrient(label: 'Vitamin K', unit: 'μg'),
    'thiamin': CanonicalNutrient(label: 'Vitamin B1', unit: 'mg'),
    'vitaminb1': CanonicalNutrient(label: 'Vitamin B1', unit: 'mg'),
    'riboflavin': CanonicalNutrient(label: 'Vitamin B2', unit: 'mg'),
    'vitaminb2': CanonicalNutrient(label: 'Vitamin B2', unit: 'mg'),
    'niacin': CanonicalNutrient(label: 'Niacin', unit: 'mg'),
    'vitaminb6': CanonicalNutrient(label: 'Vitamin B6', unit: 'mg'),
    'vitaminb12': CanonicalNutrient(label: 'Vitamin B12', unit: 'μg'),
    'folate': CanonicalNutrient(label: 'Folate', unit: 'μg'),
    'pantothenate': CanonicalNutrient(label: 'Pantothenate', unit: 'mg'),
    'biotin': CanonicalNutrient(label: 'Biotin', unit: 'μg'),
    'vitaminc': CanonicalNutrient(label: 'Vitamin C', unit: 'mg'),
    'salt equivalent': CanonicalNutrient(label: 'Salt equivalent', unit: 'g'),
    'cholesterol': CanonicalNutrient(label: 'Cholesterol', unit: 'mg'),
  };

  CanonicalNutrient? lookup(String aliasKey) {
    return aliases[aliasKey];
  }
}
