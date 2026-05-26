import '../data/importer_registry.dart';
import '../data/national_food_sources.dart';

enum SourceLicenseStatus { open, manualOnly, blocked, unknown }

enum SourceParseRisk { low, medium, high }

class SourceCapability {
  const SourceCapability({
    required this.importerId,
    required this.displayName,
    required this.country,
    required this.licenseStatus,
    required this.parseRisk,
    required this.latestReleaseLabel,
    required this.estimatedPackageBytes,
    required this.supportsAutoGrab,
    required this.supportsAutomaticFetch,
    required this.isIntegrated,
    this.blockedReason = '',
  });

  final String importerId;
  final String displayName;
  final String country;
  final SourceLicenseStatus licenseStatus;
  final SourceParseRisk parseRisk;
  final String latestReleaseLabel;
  final int estimatedPackageBytes;
  final bool supportsAutoGrab;
  final bool supportsAutomaticFetch;
  final bool isIntegrated;
  final String blockedReason;

  bool get isBlocked => licenseStatus == SourceLicenseStatus.blocked;

  bool get isManualOnly =>
      licenseStatus == SourceLicenseStatus.manualOnly ||
      !supportsAutomaticFetch;
}

class SourceCapabilityRegistry {
  SourceCapabilityRegistry({
    required List<ImporterDescriptor> importerDescriptors,
    required List<AdministrativeFoodEntity> entities,
  }) {
    final sourceById = {
      for (final entity in entities)
        for (final source in entity.sources) source.id: source,
    };
    for (final descriptor in importerDescriptors) {
      final source = sourceById[descriptor.importerId];
      _capabilities[descriptor.importerId] = _fromDescriptor(
        descriptor,
        source,
      );
    }
    for (final source in sourceById.values) {
      _capabilities.putIfAbsent(source.id, () => _fromCatalogOnly(source));
    }
  }

  final Map<String, SourceCapability> _capabilities = {};

  List<SourceCapability> get all =>
      _capabilities.values.toList()
        ..sort((left, right) => left.country.compareTo(right.country));

  SourceCapability? byImporterId(String importerId) =>
      _capabilities[importerId];

  List<String> get automaticImporterIds => all
      .where((capability) => capability.supportsAutomaticFetch)
      .map((capability) => capability.importerId)
      .toList(growable: false);

  SourceCapability _fromDescriptor(
    ImporterDescriptor descriptor,
    NationalFoodSource? source,
  ) {
    final automaticIds = {'usda', 'canada-cnf', 'uk-mccance', 'jp-standard'};
    return SourceCapability(
      importerId: descriptor.importerId,
      displayName: descriptor.displayName,
      country: descriptor.country,
      licenseStatus: _licenseStatus(source, descriptor),
      parseRisk: _parseRisk(descriptor.inputKind),
      latestReleaseLabel: source?.latestReleaseLabel ?? '',
      estimatedPackageBytes: _estimatedPackageBytes(descriptor.importerId),
      supportsAutoGrab: descriptor.supportsAutoGrab,
      supportsAutomaticFetch:
          automaticIds.contains(descriptor.importerId) &&
          descriptor.isIntegrated,
      isIntegrated: descriptor.isIntegrated,
      blockedReason: _blockedReason(source),
    );
  }

  SourceCapability _fromCatalogOnly(NationalFoodSource source) {
    return SourceCapability(
      importerId: source.id,
      displayName: source.name,
      country: source.country,
      licenseStatus: _blockedReason(source).isEmpty
          ? SourceLicenseStatus.unknown
          : SourceLicenseStatus.blocked,
      parseRisk: SourceParseRisk.high,
      latestReleaseLabel: source.latestReleaseLabel,
      estimatedPackageBytes: _estimatedPackageBytes(source.id),
      supportsAutoGrab: false,
      supportsAutomaticFetch: false,
      isIntegrated: source.isIntegrated,
      blockedReason: _blockedReason(source),
    );
  }

  SourceLicenseStatus _licenseStatus(
    NationalFoodSource? source,
    ImporterDescriptor descriptor,
  ) {
    final blocked = _blockedReason(source);
    if (blocked.isNotEmpty) {
      return SourceLicenseStatus.blocked;
    }
    if (!descriptor.supportsAutoGrab || !descriptor.isIntegrated) {
      return SourceLicenseStatus.manualOnly;
    }
    return SourceLicenseStatus.open;
  }

  String _blockedReason(NationalFoodSource? source) {
    final notes = source?.notes ?? '';
    if (notes.toLowerCase().contains('blocked')) {
      return notes;
    }
    return '';
  }

  SourceParseRisk _parseRisk(ImporterInputKind inputKind) {
    return switch (inputKind) {
      ImporterInputKind.api => SourceParseRisk.low,
      ImporterInputKind.singleFile => SourceParseRisk.medium,
      ImporterInputKind.directory => SourceParseRisk.medium,
      ImporterInputKind.multiFileDirectory => SourceParseRisk.high,
    };
  }

  int _estimatedPackageBytes(String importerId) {
    return switch (importerId) {
      'usda' => 0,
      'canada-cnf' => 25 * 1024 * 1024,
      'uk-mccance' => 8 * 1024 * 1024,
      'jp-standard' => 20 * 1024 * 1024,
      'ch-swiss-food-db' => 12 * 1024 * 1024,
      'fr-ciqual' => 10 * 1024 * 1024,
      'dk-frida' => 12 * 1024 * 1024,
      'au-afcd' => 60 * 1024 * 1024,
      'nz-foodfiles' => 150 * 1024 * 1024,
      _ => 50 * 1024 * 1024,
    };
  }
}
