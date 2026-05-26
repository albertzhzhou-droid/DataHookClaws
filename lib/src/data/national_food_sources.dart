class AdministrativeFoodEntity {
  const AdministrativeFoodEntity({
    required this.code,
    required this.name,
    required this.sources,
  });

  final String code;
  final String name;
  final List<NationalFoodSource> sources;
}

class NationalFoodSource {
  const NationalFoodSource({
    required this.id,
    required this.name,
    required this.country,
    required this.authority,
    required this.endpointLabel,
    required this.officialUrl,
    required this.latestReleaseLabel,
    required this.latestReleaseDate,
    required this.status,
    required this.notes,
  });

  final String id;
  final String name;
  final String country;
  final String authority;
  final String endpointLabel;
  final String officialUrl;
  final String latestReleaseLabel;
  final String latestReleaseDate;
  final String status;
  final String notes;

  bool get isIntegrated => status == 'Integrated';
}

const nationalFoodEntities = <AdministrativeFoodEntity>[
  AdministrativeFoodEntity(
    code: 'US',
    name: 'United States',
    sources: [
      NationalFoodSource(
        id: 'usda',
        name: 'USDA FoodData Central',
        country: 'United States',
        authority: 'US Department of Agriculture',
        endpointLabel: 'REST API',
        officialUrl: 'https://fdc.nal.usda.gov/api-guide',
        latestReleaseLabel: 'Live API dataset',
        latestReleaseDate: 'rolling',
        status: 'Integrated',
        notes:
            'Live API import is already wired. Requires a FoodData Central / data.gov API key.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'CA',
    name: 'Canada',
    sources: [
      NationalFoodSource(
        id: 'canada-cnf',
        name: 'Canadian Nutrient File',
        country: 'Canada',
        authority: 'Health Canada',
        endpointLabel: 'CSV package',
        officialUrl:
            'https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data.html',
        latestReleaseLabel: 'CNF 2015 relational files',
        latestReleaseDate: '2015-01-01',
        status: 'Integrated',
        notes:
            'CSV importer is integrated, and the official CSV zip can now be auto-downloaded and extracted.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'GB',
    name: 'United Kingdom',
    sources: [
      NationalFoodSource(
        id: 'uk-mccance',
        name: 'McCance and Widdowson CoFID',
        country: 'United Kingdom',
        authority: 'UK Government / Public Health England legacy publication',
        endpointLabel: 'Excel workbook',
        officialUrl:
            'https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid',
        latestReleaseLabel: 'CoFID 2021',
        latestReleaseDate: '2021-03-19',
        status: 'Integrated',
        notes: 'Importer and official workbook auto-grab are integrated.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'JP',
    name: 'Japan',
    sources: [
      NationalFoodSource(
        id: 'jp-standard',
        name: 'Japan Standard Tables of Food Composition',
        country: 'Japan',
        authority: 'MEXT',
        endpointLabel: 'Excel workbook',
        officialUrl:
            'https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html',
        latestReleaseLabel: 'Supplemented 2023 edition',
        latestReleaseDate: '2023-00-00',
        status: 'Integrated',
        notes:
            'Importer and official workbook auto-grab are integrated. The MEXT page also shows errata updates.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'AU',
    name: 'Australia',
    sources: [
      NationalFoodSource(
        id: 'au-afcd',
        name: 'Australian Food Composition Database',
        country: 'Australia',
        authority: 'Food Standards Australia New Zealand',
        endpointLabel: 'Downloadable data files',
        officialUrl:
            'https://www.foodstandards.gov.au/science-data/food-nutrient-databases/afcd',
        latestReleaseLabel: 'AFCD',
        latestReleaseDate: '2025-12-23',
        status: 'Integrated',
        notes:
            'Official data-file importer and multi-file auto-grab are integrated.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'NZ',
    name: 'New Zealand',
    sources: [
      NationalFoodSource(
        id: 'nz-foodfiles',
        name: 'New Zealand FOODfiles',
        country: 'New Zealand',
        authority: 'New Zealand Food Composition Database',
        endpointLabel: 'MSI package with ASCII and Excel files',
        officialUrl: 'https://foodcomposition.co.nz/foodfiles/',
        latestReleaseLabel: 'FOODfiles 2024 Version 01',
        latestReleaseDate: '2024-08-01',
        status: 'Blocked',
        notes:
            'Official source confirmed, but current Terms of Use require the data to be presented in original and unaltered form. That conflicts with the app normalization/canonical pipeline, so importer work is blocked pending a product/legal decision.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'FR',
    name: 'France',
    sources: [
      NationalFoodSource(
        id: 'fr-ciqual',
        name: 'ANSES-CIQUAL',
        country: 'France',
        authority: 'ANSES',
        endpointLabel: 'Web table + downloadable files',
        officialUrl: 'https://ciqual.anses.fr/cms/en/2025-anses-ciqual-table',
        latestReleaseLabel: 'CIQUAL 2025',
        latestReleaseDate: '2025-11-03',
        status: 'Integrated',
        notes:
            'Official Excel importer and auto-grab of the CIQUAL 2025 workbook are integrated.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'FI',
    name: 'Finland',
    sources: [
      NationalFoodSource(
        id: 'fi-fineli',
        name: 'Fineli Open Data',
        country: 'Finland',
        authority: 'Finnish Institute for Health and Welfare',
        endpointLabel: 'Open data CSV package',
        officialUrl: 'https://fineli.fi/fineli/en/avoin-data',
        latestReleaseLabel: 'Open data packages',
        latestReleaseDate: '2019-06-27',
        status: 'Blocked',
        notes:
            'Open-data CSV packaging is documented, but the official Fineli page currently redirects to THL maintenance, so importer implementation is blocked until the CSV package and current license path can be verified.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'DK',
    name: 'Denmark',
    sources: [
      NationalFoodSource(
        id: 'dk-frida',
        name: 'Frida',
        country: 'Denmark',
        authority: 'DTU National Food Institute',
        endpointLabel: 'Web database + dataset download',
        officialUrl: 'https://frida.fooddata.dk/?lang=en',
        latestReleaseLabel: 'Frida 5.5',
        latestReleaseDate: '2025-12-19',
        status: 'Integrated',
        notes:
            'Spreadsheet importer is integrated. Automatic download is not enabled because Frida sends dataset links through an official email form.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'DE',
    name: 'Germany',
    sources: [
      NationalFoodSource(
        id: 'de-bls',
        name: 'Bundeslebensmittelschlussel',
        country: 'Germany',
        authority: 'Max Rubner-Institut',
        endpointLabel: 'Free national database',
        officialUrl: 'https://www.blsdb.de/',
        latestReleaseLabel: 'BLS 4.0',
        latestReleaseDate: '2025-12-17',
        status: 'Integrated',
        notes:
            'Official BLS 4.0 workbook importer is integrated. The current release is published as open data under CC BY 4.0 on the official BLS download page.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'CH',
    name: 'Switzerland',
    sources: [
      NationalFoodSource(
        id: 'ch-swiss-food-db',
        name: 'Swiss Food Composition Database',
        country: 'Switzerland',
        authority: 'Federal Food Safety and Veterinary Office',
        endpointLabel: 'Excel download + API docs',
        officialUrl: 'https://naehrwertdaten.ch/en/downloads/',
        latestReleaseLabel: 'Version 7.0',
        latestReleaseDate: '2025-07-02',
        status: 'Integrated',
        notes: 'Official Excel importer and workbook auto-grab are integrated.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'ES',
    name: 'Spain',
    sources: [
      NationalFoodSource(
        id: 'es-bedca',
        name: 'BEDCA',
        country: 'Spain',
        authority: 'AESAN / BEDCA',
        endpointLabel: 'Web database',
        officialUrl: 'https://www.bedca.net/',
        latestReleaseLabel: 'BEDCA public database',
        latestReleaseDate: '2010-01-01',
        status: 'Blocked',
        notes:
            'Official public database is online, but no official single-workbook path is exposed. Reuse conditions require attribution and no alteration of the original meaning, so importer work needs a web/API design and license review first.',
      ),
    ],
  ),
  AdministrativeFoodEntity(
    code: 'IT',
    name: 'Italy',
    sources: [
      NationalFoodSource(
        id: 'it-crea',
        name: 'CREA Food Composition Tables',
        country: 'Italy',
        authority: 'CREA Food and Nutrition',
        endpointLabel: 'Web portal',
        officialUrl:
            'https://www.crea.gov.it/en/-/tabella-di-composizione-degli-alimenti',
        latestReleaseLabel: 'Aggiornamento 2019 website tables',
        latestReleaseDate: '2019-12-01',
        status: 'Integrated',
        notes:
            'Live importer is integrated against the official AlimentiNUTrizione search/detail portal and preserves CREA source attribution in imported records.',
      ),
    ],
  ),
];

final nationalFoodSources = nationalFoodEntities
    .expand((entity) => entity.sources)
    .toList(growable: false);
