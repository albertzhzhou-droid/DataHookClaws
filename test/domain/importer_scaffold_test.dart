import 'dart:io';

import 'package:data_hook_claws/src/tooling/importer_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('scaffold service creates importer, test, and todo files', () async {
    final root = await Directory.systemTemp.createTemp('importer-scaffold');
    addTearDown(() async {
      if (root.existsSync()) {
        await root.delete(recursive: true);
      }
    });

    final templateDir = Directory(
      p.join(root.path, 'tool', 'importer_templates'),
    )..createSync(recursive: true);
    File(
      p.join(templateDir.path, 'single_excel_importer.stub'),
    ).writeAsStringSync('class {{IMPORTER_CLASS_NAME}} {}');
    File(
      p.join(templateDir.path, 'importer_test.stub'),
    ).writeAsStringSync('test {{IMPORTER_ID}}');

    final queueFile = File(p.join(root.path, 'tool', 'queue.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
[
  {
    "countryCode": "CH",
    "countryName": "Switzerland",
    "importerId": "ch-swiss-food-db",
    "templateKind": "single_excel",
    "status": "queued",
    "blockedReason": "",
    "officialSourceUrl": "https://example.com"
  }
]
''');

    final service = const ImporterScaffoldService();
    final items = service.readQueue(queueFile);
    final result = service.scaffold(projectRoot: root, item: items.single);

    expect(File(result.importerFilePath).existsSync(), isTrue);
    expect(File(result.testFilePath).existsSync(), isTrue);
    expect(File(result.readmeTodoPath).existsSync(), isTrue);
    expect(
      File(result.importerFilePath).readAsStringSync(),
      contains('ChSwissFoodDbImporter'),
    );
  });
}
