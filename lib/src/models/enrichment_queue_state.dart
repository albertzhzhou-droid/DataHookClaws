enum EnrichmentStatus { idle, enriching, completed, failed }

class EnrichmentQueueState {
  const EnrichmentQueueState({
    required this.activeQuery,
    required this.status,
    required this.activeSources,
    required this.lastMessage,
  });

  final String? activeQuery;
  final EnrichmentStatus status;
  final List<String> activeSources;
  final String? lastMessage;

  factory EnrichmentQueueState.idle() {
    return const EnrichmentQueueState(
      activeQuery: null,
      status: EnrichmentStatus.idle,
      activeSources: [],
      lastMessage: null,
    );
  }

  EnrichmentQueueState copyWith({
    String? activeQuery,
    bool clearActiveQuery = false,
    EnrichmentStatus? status,
    List<String>? activeSources,
    String? lastMessage,
  }) {
    return EnrichmentQueueState(
      activeQuery: clearActiveQuery ? null : activeQuery ?? this.activeQuery,
      status: status ?? this.status,
      activeSources: activeSources ?? this.activeSources,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}
