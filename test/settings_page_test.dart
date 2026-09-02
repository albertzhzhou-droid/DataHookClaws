import 'dart:convert';

import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/settings_service.dart';
import 'package:data_hook_claws/src/domain/source_capability_registry.dart';
import 'package:data_hook_claws/src/features/settings/settings_page.dart';
import 'package:data_hook_claws/src/models/storage_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings page keeps defaults visible when paths are unavailable',
    (tester) async {
      final repository = MemoryFoodRepository();
      final settingsService = _settingsService(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            settingsService: settingsService,
            sourceCapabilities: _sourceCapabilities(),
            storagePathsLoader: () async {
              throw StateError('storage paths unavailable');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not load storage paths'),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('llama3'), findsOneWidget);
    },
  );

  testWidgets('settings page reports save failures without losing the form', (
    tester,
  ) async {
    final repository = _SettingsPageRepository();
    final settingsService = _settingsService(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settingsService: settingsService,
          sourceCapabilities: _sourceCapabilities(),
          storagePathsLoader: () async => const StoragePaths(
            databasePath: '/tmp/database.sqlite',
            documentsPath: '/tmp/documents',
            exportsPath: '/tmp/exports',
            cachePath: '/tmp/cache',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.failWrites = true;

    final saveButton = find.widgetWithText(FilledButton, 'Save settings');
    await tester.scrollUntilVisible(
      saveButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(saveButton, findsOneWidget);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save settings'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
  });

  testWidgets(
    'settings page reflects the sanitized snapshot after saving unsafe values',
    (tester) async {
      final repository = MemoryFoodRepository();
      final settingsService = _settingsService(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            settingsService: settingsService,
            sourceCapabilities: _sourceCapabilities(),
            storagePathsLoader: () async => const StoragePaths(
              databasePath: '/tmp/database.sqlite',
              documentsPath: '/tmp/documents',
              exportsPath: '/tmp/exports',
              cachePath: '/tmp/cache',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> enterField(String label, String value) async {
        final labelFinder = find.text(label);
        await tester.scrollUntilVisible(
          labelFinder,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        final field = find
            .ancestor(of: labelFinder, matching: find.byType(TextField))
            .first;
        await tester.enterText(field, value);
      }

      await enterField('Model max calls per minute', '-1');
      await enterField('Model timeout seconds', '0');
      await enterField('Model max tokens', '-20');
      await enterField('Database budget bytes', '-1');
      await enterField('Artifact budget bytes', '0');
      await enterField('Export budget bytes', '-5');
      await enterField('Cache budget bytes', '-10');

      final saveButton = find.widgetWithText(FilledButton, 'Save settings');
      await tester.scrollUntilVisible(
        saveButton,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final persisted =
          jsonDecode(
                (await repository.getAppMeta(SettingsService.settingsKey))!,
              )
              as Map<String, dynamic>;
      expect(persisted['modelMaxCallsPerMinute'], 6);
      expect(persisted['modelTimeoutSeconds'], 3);
      expect(persisted['modelMaxTokens'], 256);
      expect(persisted['databaseBudgetBytes'], 512 * 1024 * 1024);
      expect(persisted['artifactBudgetBytes'], 2 * 1024 * 1024 * 1024);
      expect(persisted['exportBudgetBytes'], 1024 * 1024 * 1024);
      expect(persisted['cacheBudgetBytes'], 512 * 1024 * 1024);
    },
  );
}

SettingsService _settingsService(MemoryFoodRepository repository) {
  return SettingsService(
    repository: repository,
    sourceCapabilities: _sourceCapabilities(),
  );
}

SourceCapabilityRegistry _sourceCapabilities() {
  return SourceCapabilityRegistry(
    importerDescriptors: importerDescriptors,
    entities: nationalFoodEntities,
  );
}

class _SettingsPageRepository extends MemoryFoodRepository {
  bool failWrites = false;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failWrites && key == SettingsService.settingsKey) {
      throw StateError('settings write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}
