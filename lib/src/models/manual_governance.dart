class CanonicalOverrideFields {
  const CanonicalOverrideFields({
    this.displayName,
    this.category,
    this.countryHint,
    this.description,
    this.servingBasis,
  });

  final String? displayName;
  final String? category;
  final String? countryHint;
  final String? description;
  final String? servingBasis;

  bool get isEmpty =>
      _blank(displayName) &&
      _blank(category) &&
      _blank(countryHint) &&
      _blank(description) &&
      _blank(servingBasis);

  bool _blank(String? value) => value == null || value.trim().isEmpty;
}

class ManualGovernanceLogEntry {
  const ManualGovernanceLogEntry({
    required this.id,
    required this.action,
    required this.sourceRecordId,
    required this.fromCanonicalFoodId,
    required this.toCanonicalFoodId,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String sourceRecordId;
  final String fromCanonicalFoodId;
  final String toCanonicalFoodId;
  final String note;
  final DateTime createdAt;
}
