import '../models/food_item.dart';
import '../models/ai_suggestion_log_entry.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/fetch_job_entry.dart';
import '../models/food_details.dart';
import '../models/food_summary.dart';
import '../models/import_log_entry.dart';

abstract class FoodRepository {
  Future<void> initialize();

  Future<List<FoodItem>> getAllFoods();

  Future<List<FoodItem>> searchFoods(String query);

  Future<List<FoodSummary>> searchFoodSummaries(String query, {int limit = 20});

  Future<List<FoodSummary>> searchFoodSummariesByCountry(
    String country, {
    int limit = 1000,
  });

  Future<FoodDetails?> getFoodDetails(String canonicalFoodId);

  Future<int> countFoods();

  Future<void> upsertFoods(List<FoodItem> incomingItems);

  Future<void> addImportLog(ImportLogEntry entry);

  Future<List<ImportLogEntry>> getImportLogs({int limit = 20});

  Future<void> upsertFetchJob(FetchJobEntry entry);

  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    int limit = 20,
  });

  Future<FetchJobEntry?> getLatestFetchJobForQuery({
    required String query,
    required String phase,
  });

  Future<void> addAiSuggestionLog(AiSuggestionLogEntry entry);

  Future<List<AiSuggestionLogEntry>> getAiSuggestionLogs({int limit = 20});

  Future<void> upsertDatasetArtifact(DatasetArtifactEntry entry);

  Future<void> copyDatabaseSnapshot({required String destinationPath});
}
