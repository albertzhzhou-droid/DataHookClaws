import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ImporterQueueItem {
  const ImporterQueueItem({
    required this.countryCode,
    required this.countryName,
    required this.importerId,
    required this.templateKind,
    required this.status,
    required this.blockedReason,
    required this.officialSourceUrl,
  });

  final String countryCode;
  final String countryName;
  final String importerId;
  final String templateKind;
  final String status;
  final String blockedReason;
  final String officialSourceUrl;

  factory ImporterQueueItem.fromJson(Map<String, Object?> json) {
    return ImporterQueueItem(
      countryCode: json['countryCode']! as String,
      countryName: json['countryName']! as String,
      importerId: json['importerId']! as String,
      templateKind: json['templateKind']! as String,
      status: json['status']! as String,
      blockedReason: (json['blockedReason'] ?? '') as String,
      officialSourceUrl: json['officialSourceUrl']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'countryCode': countryCode,
      'countryName': countryName,
      'importerId': importerId,
      'templateKind': templateKind,
      'status': status,
      'blockedReason': blockedReason,
      'officialSourceUrl': officialSourceUrl,
    };
  }
}

class ImporterScaffoldResult {
  const ImporterScaffoldResult({
    required this.importerFilePath,
    required this.testFilePath,
    required this.readmeTodoPath,
  });

  final String importerFilePath;
  final String testFilePath;
  final String readmeTodoPath;
}

class ImporterScaffoldService {
  const ImporterScaffoldService();

  List<ImporterQueueItem> readQueue(File queueFile) {
    final raw = jsonDecode(queueFile.readAsStringSync()) as List<Object?>;
    return raw
        .map(
          (item) => ImporterQueueItem.fromJson(item! as Map<String, Object?>),
        )
        .toList(growable: false);
  }

  void writeQueue(File queueFile, List<ImporterQueueItem> items) {
    queueFile.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  ImporterScaffoldResult scaffold({
    required Directory projectRoot,
    required ImporterQueueItem item,
  }) {
    final templateDirectory = Directory(
      p.join(projectRoot.path, 'tool', 'importer_templates'),
    );
    final importerTemplate = File(
      p.join(templateDirectory.path, '${item.templateKind}_importer.stub'),
    );
    final testTemplate = File(
      p.join(templateDirectory.path, 'importer_test.stub'),
    );
    if (!importerTemplate.existsSync()) {
      throw StateError('Missing importer template: ${importerTemplate.path}');
    }
    if (!testTemplate.existsSync()) {
      throw StateError('Missing importer test template: ${testTemplate.path}');
    }

    final importerFileName = '${_snakeCase(item.importerId)}_importer.dart';
    final importerClassName = _className(item.importerId);
    final importerFile = File(
      p.join(projectRoot.path, 'lib', 'src', 'importers', importerFileName),
    );
    final testFile = File(
      p.join(
        projectRoot.path,
        'test',
        'domain',
        '${_snakeCase(item.importerId)}_importer_test.dart',
      ),
    );
    final todoFile = File(
      p.join(
        projectRoot.path,
        'tool',
        'importer_templates',
        'generated',
        '${item.countryCode.toLowerCase()}_todo.md',
      ),
    );

    importerFile.parent.createSync(recursive: true);
    testFile.parent.createSync(recursive: true);
    todoFile.parent.createSync(recursive: true);

    importerFile.writeAsStringSync(
      _fillTemplate(
        importerTemplate.readAsStringSync(),
        item: item,
        importerClassName: importerClassName,
        importerFileName: importerFileName,
      ),
    );
    testFile.writeAsStringSync(
      _fillTemplate(
        testTemplate.readAsStringSync(),
        item: item,
        importerClassName: importerClassName,
        importerFileName: importerFileName,
      ),
    );
    todoFile.writeAsStringSync(
      [
        '# ${item.countryName} importer follow-up',
        '',
        '- Fill real workbook/package parsing logic.',
        '- Register the importer descriptor and factory hook.',
        '- Update README.md, AGENT.md, and docs/PROJECT_PLAN.md.',
        '- Run flutter analyze and flutter test.',
      ].join('\n'),
    );

    return ImporterScaffoldResult(
      importerFilePath: importerFile.path,
      testFilePath: testFile.path,
      readmeTodoPath: todoFile.path,
    );
  }

  String _fillTemplate(
    String template, {
    required ImporterQueueItem item,
    required String importerClassName,
    required String importerFileName,
  }) {
    return template
        .replaceAll('{{COUNTRY_CODE}}', item.countryCode)
        .replaceAll('{{COUNTRY_NAME}}', item.countryName)
        .replaceAll('{{IMPORTER_ID}}', item.importerId)
        .replaceAll('{{IMPORTER_CLASS_NAME}}', importerClassName)
        .replaceAll('{{IMPORTER_FILE_NAME}}', importerFileName)
        .replaceAll('{{OFFICIAL_SOURCE_URL}}', item.officialSourceUrl);
  }

  String _snakeCase(String value) {
    return value.replaceAll('-', '_');
  }

  String _className(String importerId) {
    return '${importerId.split(RegExp(r'[-_]')).map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join()}Importer';
  }
}
