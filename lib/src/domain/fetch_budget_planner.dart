class FetchPlan {
  const FetchPlan({
    required this.shouldFetch,
    required this.importerIds,
    required this.limitPerImporter,
  });

  final bool shouldFetch;
  final List<String> importerIds;
  final int limitPerImporter;
}

class FetchBudgetPlanner {
  const FetchBudgetPlanner({
    this.maxImporters = 2,
    this.limitPerImporter = 20,
    this.localHitThreshold = 10,
    this.prioritizedImporters = const [
      'usda',
      'canada-cnf',
      'uk-mccance',
      'jp-standard',
    ],
  });

  final int maxImporters;
  final int limitPerImporter;
  final int localHitThreshold;
  final List<String> prioritizedImporters;

  FetchPlan plan({
    required String query,
    required int localHitCount,
    List<String> sourceHints = const [],
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || localHitCount >= localHitThreshold) {
      return const FetchPlan(
        shouldFetch: false,
        importerIds: [],
        limitPerImporter: 20,
      );
    }

    final hinted = sourceHints
        .where(prioritizedImporters.contains)
        .toList(growable: false);
    final ordered = [
      ...hinted,
      ...prioritizedImporters.where((item) => !hinted.contains(item)),
    ].take(maxImporters).toList(growable: false);

    return FetchPlan(
      shouldFetch: true,
      importerIds: ordered,
      limitPerImporter: limitPerImporter,
    );
  }
}
