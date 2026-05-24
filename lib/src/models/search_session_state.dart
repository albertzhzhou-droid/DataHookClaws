import 'food_item.dart';

enum SearchStatus { idle, local, fetching, archived, failed }

class SearchSessionState {
  const SearchSessionState({
    required this.query,
    required this.localResults,
    required this.foregroundFetchedResults,
    required this.combinedResults,
    required this.status,
    required this.activeSources,
    required this.message,
  });

  final String query;
  final List<FoodItem> localResults;
  final List<FoodItem> foregroundFetchedResults;
  final List<FoodItem> combinedResults;
  final SearchStatus status;
  final List<String> activeSources;
  final String? message;

  factory SearchSessionState.idle() {
    return const SearchSessionState(
      query: '',
      localResults: [],
      foregroundFetchedResults: [],
      combinedResults: [],
      status: SearchStatus.idle,
      activeSources: [],
      message: null,
    );
  }

  SearchSessionState copyWith({
    String? query,
    List<FoodItem>? localResults,
    List<FoodItem>? foregroundFetchedResults,
    List<FoodItem>? combinedResults,
    SearchStatus? status,
    List<String>? activeSources,
    String? message,
  }) {
    return SearchSessionState(
      query: query ?? this.query,
      localResults: localResults ?? this.localResults,
      foregroundFetchedResults:
          foregroundFetchedResults ?? this.foregroundFetchedResults,
      combinedResults: combinedResults ?? this.combinedResults,
      status: status ?? this.status,
      activeSources: activeSources ?? this.activeSources,
      message: message ?? this.message,
    );
  }
}
