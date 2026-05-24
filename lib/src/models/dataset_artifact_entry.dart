class DatasetArtifactEntry {
  const DatasetArtifactEntry({
    required this.id,
    required this.importerId,
    required this.artifactType,
    required this.localPath,
    required this.sourceUrl,
    required this.sourceVersion,
    required this.fetchedAt,
    required this.status,
  });

  final String id;
  final String importerId;
  final String artifactType;
  final String localPath;
  final String sourceUrl;
  final String sourceVersion;
  final DateTime fetchedAt;
  final String status;
}
