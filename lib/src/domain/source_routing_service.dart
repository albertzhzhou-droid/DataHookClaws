import '../models/fetch_job_entry.dart';
import 'source_capability_registry.dart';

class SourceRoutingService {
  const SourceRoutingService({
    required SourceCapabilityRegistry registry,
    Set<String> disabledSourceIds = const {},
  }) : _registry = registry,
       _disabledSourceIds = disabledSourceIds;

  final SourceCapabilityRegistry _registry;
  final Set<String> _disabledSourceIds;

  List<String> route({
    required List<String> defaultOrder,
    required List<String> sourceHints,
    required List<FetchJobEntry> recentFailures,
    required int maxImporters,
  }) {
    final failedImporterIds = recentFailures
        .where((job) => job.status == 'failure')
        .map((job) => job.importerId)
        .toSet();
    final eligible = defaultOrder.where(_canAutoFetch).toList(growable: false);
    final hinted = sourceHints
        .where(eligible.contains)
        .where((id) => !failedImporterIds.contains(id))
        .toList(growable: false);
    final healthy = eligible
        .where((id) => !hinted.contains(id))
        .where((id) => !failedImporterIds.contains(id));
    final failedButAllowed = eligible
        .where((id) => !hinted.contains(id))
        .where(failedImporterIds.contains);

    return [
      ...hinted,
      ...healthy,
      ...failedButAllowed,
    ].take(maxImporters).toList(growable: false);
  }

  bool _canAutoFetch(String importerId) {
    final capability = _registry.byImporterId(importerId);
    return capability != null &&
        !_disabledSourceIds.contains(importerId) &&
        capability.supportsAutomaticFetch &&
        !capability.isBlocked;
  }
}
