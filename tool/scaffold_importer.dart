import 'dart:io';

import 'package:data_hook_claws/src/tooling/importer_scaffold.dart';

void main(List<String> args) {
  final service = const ImporterScaffoldService();
  final root = Directory.current;
  final queueFile = File('${root.path}/tool/importer_expansion_queue.json');
  final countryCode = args.isEmpty ? '' : args.first.trim().toUpperCase();
  final items = service.readQueue(queueFile);
  final target = items.firstWhere(
    (item) => item.countryCode == countryCode,
    orElse: () => throw StateError(
      'Country code $countryCode was not found in importer_expansion_queue.json.',
    ),
  );

  final result = service.scaffold(projectRoot: root, item: target);
  stdout.writeln('Importer scaffolded: ${result.importerFilePath}');
  stdout.writeln('Test scaffolded: ${result.testFilePath}');
  stdout.writeln('Follow-up todo: ${result.readmeTodoPath}');
}
