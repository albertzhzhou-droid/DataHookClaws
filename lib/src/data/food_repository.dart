import '../models/food_item.dart';
import '../models/ai_suggestion_log_entry.dart';
import '../models/export_history_entry.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/fetch_job_entry.dart';
import '../models/food_details.dart';
import '../models/food_search_query.dart';
import '../models/food_summary.dart';
import '../models/import_log_entry.dart';
import '../models/manual_governance.dart';
import '../models/merge_review_issue.dart';
import '../models/storage_paths.dart';

abstract class FoodRepository {
  Future<void> initialize();

  Future<List<FoodItem>> getAllFoods();

  Future<List<FoodItem>> searchFoods(String query);

  Future<List<FoodItem>> searchFoodsAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  });

  Future<List<FoodSummary>> searchFoodSummaries(String query, {int limit = 20});

  Future<List<FoodSummary>> searchFoodSummariesAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  });

  Future<List<FoodSummary>> searchFoodSummariesByCountry(
    String country, {
    int limit = 1000,
  });

  Future<FoodDetails?> getFoodDetails(String canonicalFoodId);

  Future<List<MergeReviewIssue>> getMergeReviewIssues({int limit = 100});

  Future<void> mergeSourceRecord({
    required String sourceRecordId,
    required String targetCanonicalFoodId,
    required String note,
  });

  Future<void> splitSourceRecord({
    required String sourceRecordId,
    required String note,
  });

  Future<void> overrideCanonicalFood({
    required String canonicalFoodId,
    required CanonicalOverrideFields fields,
    required String note,
  });

  Future<List<ManualGovernanceLogEntry>> getManualGovernanceLogs({
    int limit = 50,
  });

  Future<int> countFoods();

  Future<void> upsertFoods(List<FoodItem> incomingItems);

  Future<void> addImportLog(ImportLogEntry entry);

  Future<List<ImportLogEntry>> getImportLogs({int limit = 20});

  Future<void> upsertFetchJob(FetchJobEntry entry);

  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    String? importerId,
    String? status,
    int limit = 20,
  });

  Future<FetchJobEntry?> getLatestFetchJobForQuery({
    required String query,
    required String phase,
  });

  Future<void> addAiSuggestionLog(AiSuggestionLogEntry entry);

  Future<List<AiSuggestionLogEntry>> getAiSuggestionLogs({int limit = 20});

  Future<String?> getAppMeta(String key);

  Future<void> setAppMeta(String key, String value);

  Future<void> upsertDatasetArtifact(DatasetArtifactEntry entry);

  Future<List<DatasetArtifactEntry>> getDatasetArtifacts({int limit = 50});

  Future<void> markDatasetArtifactRemoved(String id);

  Future<StoragePaths> getStoragePaths();

  Future<void> copyDatabaseSnapshot({required String destinationPath});

  Future<void> addExportHistory(ExportHistoryEntry entry);

  Future<List<ExportHistoryEntry>> getExportHistory({int limit = 20});
}
