enum OfficialDatasetPackaging {
  singleFile,
  zipDirectory,
  downloadedDirectory,
  installerFile,
}

class OfficialDatasetDownload {
  const OfficialDatasetDownload.direct({
    required this.suggestedFileName,
    required this.directUrl,
  }) : discovery = null;

  const OfficialDatasetDownload.discovered({
    required this.suggestedFileName,
    required this.discovery,
  }) : directUrl = null;

  final String suggestedFileName;
  final String? directUrl;
  final PageLinkDiscovery? discovery;
}

class PageLinkDiscovery {
  const PageLinkDiscovery({required this.containsAll, this.fileExtension});

  final List<String> containsAll;
  final String? fileExtension;
}

class OfficialDatasetManifestEntry {
  const OfficialDatasetManifestEntry({
    required this.importerId,
    required this.sourcePageUrl,
    required this.sourceLabel,
    required this.packaging,
    required this.downloads,
  });

  final String importerId;
  final String sourcePageUrl;
  final String sourceLabel;
  final OfficialDatasetPackaging packaging;
  final List<OfficialDatasetDownload> downloads;
}

const officialDatasetManifest = <String, OfficialDatasetManifestEntry>{
  'canada-cnf': OfficialDatasetManifestEntry(
    importerId: 'canada-cnf',
    sourcePageUrl:
        'https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data/canadian-nutrient-file-2015-download-files.html',
    sourceLabel: 'Health Canada CNF 2015 CSV package',
    packaging: OfficialDatasetPackaging.zipDirectory,
    downloads: [
      OfficialDatasetDownload.direct(
        suggestedFileName: 'cnf_fcen_csv.zip',
        directUrl:
            'https://www.canada.ca/content/dam/hc-sc/migration/hc-sc/fn-an/alt_formats/zip/nutrition/fiche-nutri-data/cnf-fcen-csv.zip',
      ),
    ],
  ),
  'uk-mccance': OfficialDatasetManifestEntry(
    importerId: 'uk-mccance',
    sourcePageUrl:
        'https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid',
    sourceLabel: 'GOV.UK CoFID 2021 workbook',
    packaging: OfficialDatasetPackaging.singleFile,
    downloads: [
      OfficialDatasetDownload.direct(
        suggestedFileName: 'uk_cofid_2021.xlsx',
        directUrl:
            'https://assets.publishing.service.gov.uk/media/605b37ba8fa8f57ce6e23a43/McCance_and_Widdowsons_Composition_of_Foods_Integrated_Dataset_2021.xlsx',
      ),
    ],
  ),
  'jp-standard': OfficialDatasetManifestEntry(
    importerId: 'jp-standard',
    sourcePageUrl:
        'https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html',
    sourceLabel: 'MEXT Japan Standard Tables 2023 workbook',
    packaging: OfficialDatasetPackaging.singleFile,
    downloads: [
      OfficialDatasetDownload.direct(
        suggestedFileName: 'japan_mext_2023.xlsx',
        directUrl:
            'https://www.mext.go.jp/content/20230428-mxt_kagsei-mext_01110_012.xlsx',
      ),
    ],
  ),
  'au-afcd': OfficialDatasetManifestEntry(
    importerId: 'au-afcd',
    sourcePageUrl:
        'https://www.foodstandards.gov.au/science-data/food-nutrient-databases/afcd/data-files',
    sourceLabel: 'FSANZ AFCD data files',
    packaging: OfficialDatasetPackaging.downloadedDirectory,
    downloads: [
      OfficialDatasetDownload.discovered(
        suggestedFileName: 'afcd_food_details.xlsx',
        discovery: PageLinkDiscovery(
          containsAll: ['food details'],
          fileExtension: '.xlsx',
        ),
      ),
      OfficialDatasetDownload.discovered(
        suggestedFileName: 'afcd_nutrient_profiles.xlsx',
        discovery: PageLinkDiscovery(
          containsAll: ['nutrient profiles'],
          fileExtension: '.xlsx',
        ),
      ),
    ],
  ),
  'ch-swiss-food-db': OfficialDatasetManifestEntry(
    importerId: 'ch-swiss-food-db',
    sourcePageUrl: 'https://naehrwertdaten.ch/en/downloads/',
    sourceLabel: 'Swiss food composition database Excel export',
    packaging: OfficialDatasetPackaging.singleFile,
    downloads: [
      OfficialDatasetDownload.discovered(
        suggestedFileName: 'swiss_food_composition_database.xlsx',
        discovery: PageLinkDiscovery(
          containsAll: ['swiss food composition database'],
          fileExtension: '.xlsx',
        ),
      ),
    ],
  ),
  'fr-ciqual': OfficialDatasetManifestEntry(
    importerId: 'fr-ciqual',
    sourcePageUrl: 'https://ciqual.anses.fr/cms/en/2025-anses-ciqual-table',
    sourceLabel: 'ANSES-CIQUAL 2025 English workbook',
    packaging: OfficialDatasetPackaging.singleFile,
    downloads: [
      OfficialDatasetDownload.direct(
        suggestedFileName: 'table_ciqual_2025_eng_2025_11_03.xlsx',
        directUrl:
            'https://ciqual.anses.fr/cms/sites/default/files/inline-files/Table%20Ciqual%202025_ENG_2025_11_03.xlsx',
      ),
    ],
  ),
  'nz-foodfiles': OfficialDatasetManifestEntry(
    importerId: 'nz-foodfiles',
    sourcePageUrl: 'https://foodcomposition.co.nz/foodfiles/',
    sourceLabel: 'New Zealand FOODfiles MSI package',
    packaging: OfficialDatasetPackaging.installerFile,
    downloads: [
      OfficialDatasetDownload.discovered(
        suggestedFileName: 'nz_foodfiles_2024.msi',
        discovery: PageLinkDiscovery(
          containsAll: ['msi installer', 'foodfiles'],
          fileExtension: '.msi',
        ),
      ),
    ],
  ),
};
