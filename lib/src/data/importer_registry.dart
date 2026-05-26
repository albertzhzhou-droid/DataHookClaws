import '../importers/australia_afcd_importer.dart';
import '../importers/canada_cnf_csv_importer.dart';
import '../importers/de_bls_importer.dart';
import '../importers/denmark_frida_excel_importer.dart';
import '../importers/food_importer.dart';
import '../importers/france_ciqual_excel_importer.dart';
import '../importers/it_crea_importer.dart';
import '../importers/japan_standard_food_excel_importer.dart';
import '../importers/swiss_food_composition_excel_importer.dart';
import '../importers/uk_cofid_excel_importer.dart';
import '../importers/usda_food_data_importer.dart';

enum ImporterInputKind { api, singleFile, directory, multiFileDirectory }

class ImporterDescriptor {
  const ImporterDescriptor({
    required this.importerId,
    required this.displayName,
    required this.country,
    required this.inputKind,
    required this.description,
    required this.buttonLabel,
    required this.queryLabel,
    required this.queryHint,
    required this.pathLabel,
    required this.pathHint,
    required this.supportsAutoGrab,
    required this.defaultLimit,
    required this.isIntegrated,
    this.apiKeyLabel = '',
    this.apiKeyHint = '',
    this.defaultQuery = '',
    this.requiresApiKey = false,
    this.supportsQuery = true,
    this.supportsDatasetPath = true,
  });

  final String importerId;
  final String displayName;
  final String country;
  final ImporterInputKind inputKind;
  final String description;
  final String buttonLabel;
  final String queryLabel;
  final String queryHint;
  final String pathLabel;
  final String pathHint;
  final bool supportsAutoGrab;
  final int defaultLimit;
  final bool isIntegrated;
  final String apiKeyLabel;
  final String apiKeyHint;
  final String defaultQuery;
  final bool requiresApiKey;
  final bool supportsQuery;
  final bool supportsDatasetPath;
}

const importerDescriptors = <ImporterDescriptor>[
  ImporterDescriptor(
    importerId: 'usda',
    displayName: 'USDA FoodData Central',
    country: 'United States',
    inputKind: ImporterInputKind.api,
    description:
        'Live import from the official USDA API. The API requires a FoodData Central / data.gov key.',
    buttonLabel: 'Import USDA',
    queryLabel: 'Search query',
    queryHint: 'e.g. salmon, oats, tofu',
    pathLabel: '',
    pathHint: '',
    supportsAutoGrab: false,
    defaultLimit: 20,
    isIntegrated: true,
    apiKeyLabel: 'API key',
    apiKeyHint: 'Paste USDA API key',
    defaultQuery: 'salmon',
    requiresApiKey: true,
    supportsDatasetPath: false,
  ),
  ImporterDescriptor(
    importerId: 'canada-cnf',
    displayName: 'Canadian Nutrient File',
    country: 'Canada',
    inputKind: ImporterInputKind.directory,
    description:
        'Imports official CNF CSV extracts from a local folder. Leave the path empty to auto-download and extract the official CSV zip package.',
    buttonLabel: 'Import CNF CSV',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching foods',
    pathLabel: 'CSV folder path',
    pathHint: '/path/to/cnf-folder or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'uk-mccance',
    displayName: 'UK CoFID',
    country: 'United Kingdom',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official UK CoFID workbook. Leave the path empty to auto-download the official GOV.UK workbook, or provide a local .xlsx file.',
    buttonLabel: 'Import UK CoFID',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching UK foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/cofid.xlsx or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'jp-standard',
    displayName: 'Japan MEXT 2023',
    country: 'Japan',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official Japan food composition workbook. Leave the path empty to auto-download the main MEXT Excel file, or provide a local workbook.',
    buttonLabel: 'Import Japan MEXT',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching Japanese foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/japan_food_2023.xlsx or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'ch-swiss-food-db',
    displayName: 'Swiss Food Composition Database',
    country: 'Switzerland',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official Swiss food composition workbook. Leave the path empty to auto-download the Version 7.0 Excel file, or provide a local workbook.',
    buttonLabel: 'Import Switzerland',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching Swiss foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/swiss_food_composition_database.xlsx or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'fr-ciqual',
    displayName: 'France CIQUAL 2025',
    country: 'France',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official ANSES-CIQUAL 2025 English workbook. Leave the path empty to auto-download the official .xlsx workbook, or provide a local workbook.',
    buttonLabel: 'Import France CIQUAL',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching French foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/table_ciqual_2025.xlsx or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'dk-frida',
    displayName: 'Denmark Frida',
    country: 'Denmark',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official Frida spreadsheet after it has been downloaded through the DTU Frida form. Automatic download is not enabled because Frida sends dataset links by email.',
    buttonLabel: 'Import Denmark Frida',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching Danish foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/frida.xlsx',
    supportsAutoGrab: false,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'de-bls',
    displayName: 'Germany BLS 4.0',
    country: 'Germany',
    inputKind: ImporterInputKind.singleFile,
    description:
        'Imports the official BLS 4.0 workbook from the Max Rubner-Institut. Provide the downloaded main .xlsx workbook path.',
    buttonLabel: 'Import Germany BLS',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching German foods',
    pathLabel: 'Workbook path',
    pathHint: '/path/to/BLS_4_0_Daten_2025_DE.xlsx',
    supportsAutoGrab: false,
    defaultLimit: 20,
    isIntegrated: true,
  ),
  ImporterDescriptor(
    importerId: 'it-crea',
    displayName: 'Italy CREA 2019',
    country: 'Italy',
    inputKind: ImporterInputKind.api,
    description:
        'Live import from the official CREA / AlimentiNUTrizione food-composition portal. Enter a food query and the importer fetches matching official detail pages.',
    buttonLabel: 'Import Italy CREA',
    queryLabel: 'Food query',
    queryHint: 'e.g. pane, salmone, yogurt',
    pathLabel: '',
    pathHint: '',
    supportsAutoGrab: false,
    defaultLimit: 10,
    isIntegrated: true,
    defaultQuery: 'pane',
    supportsDatasetPath: false,
  ),
  ImporterDescriptor(
    importerId: 'au-afcd',
    displayName: 'Australia AFCD',
    country: 'Australia',
    inputKind: ImporterInputKind.multiFileDirectory,
    description:
        'Imports the official AFCD Excel package. Leave the path empty to auto-download the AFCD data files into a prepared folder, or provide a local directory.',
    buttonLabel: 'Import Australia AFCD',
    queryLabel: 'Optional food filter',
    queryHint: 'Import only matching Australian foods',
    pathLabel: 'Data files directory',
    pathHint: '/path/to/afcd-data-files or leave empty',
    supportsAutoGrab: true,
    defaultLimit: 20,
    isIntegrated: true,
  ),
];

List<FoodImporter> buildIntegratedImporters() {
  return [
    UsdaFoodDataImporter(),
    CanadaCnfCsvImporter(),
    UkCofidExcelImporter(),
    JapanStandardFoodExcelImporter(),
    SwissFoodCompositionExcelImporter(),
    FranceCiqualExcelImporter(),
    DenmarkFridaExcelImporter(),
    DeBlsImporter(),
    ItCreaImporter(),
    AustraliaAfcdImporter(),
  ];
}
