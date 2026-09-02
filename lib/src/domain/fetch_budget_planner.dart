import '../models/fetch_job_entry.dart';
import 'source_routing_service.dart';

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
    int maxImporters = 2,
    int limitPerImporter = 20,
    int localHitThreshold = 10,
    this.sourceRoutingService,
    this.prioritizedImporters = const [
      'usda',
      'canada-cnf',
      'uk-mccance',
      'jp-standard',
    ],
  }) : maxImporters = maxImporters < 0 ? 2 : maxImporters,
       limitPerImporter = limitPerImporter <= 0 ? 20 : limitPerImporter,
       localHitThreshold = localHitThreshold < 0 ? 10 : localHitThreshold;

  final int maxImporters;
  final int limitPerImporter;
  final int localHitThreshold;
  final SourceRoutingService? sourceRoutingService;
  final List<String> prioritizedImporters;

  FetchPlan plan({
    required String query,
    required int localHitCount,
    List<String> sourceHints = const [],
    List<FetchJobEntry> recentFailures = const [],
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || localHitCount >= localHitThreshold) {
      return FetchPlan(
        shouldFetch: false,
        importerIds: [],
        limitPerImporter: limitPerImporter,
      );
    }

    final ordered =
        sourceRoutingService?.route(
          defaultOrder: prioritizedImporters,
          sourceHints: sourceHints,
          recentFailures: recentFailures,
          maxImporters: maxImporters,
        ) ??
        _legacyRoute(sourceHints);

    return FetchPlan(
      shouldFetch: ordered.isNotEmpty,
      importerIds: ordered,
      limitPerImporter: limitPerImporter,
    );
  }

  List<String> routeRemainingImporters({
    required List<String> sourceHints,
    required List<String> alreadyTriedImporterIds,
    List<FetchJobEntry> recentFailures = const [],
  }) {
    final alreadyTried = alreadyTriedImporterIds.toSet();
    final route =
        sourceRoutingService?.route(
          defaultOrder: prioritizedImporters,
          sourceHints: sourceHints,
          recentFailures: recentFailures,
          maxImporters: prioritizedImporters.length,
        ) ??
        _legacyRoute(sourceHints, max: prioritizedImporters.length);
    return route
        .where((importerId) => !alreadyTried.contains(importerId))
        .toList(growable: false);
  }

  List<String> _legacyRoute(List<String> sourceHints, {int? max}) {
    final maxItems = max ?? maxImporters;
    final ordered = <String>[];
    for (final importerId in sourceHints) {
      if (prioritizedImporters.contains(importerId) &&
          !ordered.contains(importerId)) {
        ordered.add(importerId);
      }
    }
    for (final importerId in prioritizedImporters) {
      if (!ordered.contains(importerId)) {
        ordered.add(importerId);
      }
    }
    return ordered.take(maxItems < 0 ? 0 : maxItems).toList(growable: false);
  }
}
