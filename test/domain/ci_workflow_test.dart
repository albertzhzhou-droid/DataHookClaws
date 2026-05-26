import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GitHub Actions workflow covers analyze, tests, importers, and web', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test'));
    expect(
      workflow,
      contains(
        'flutter test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart',
      ),
    );
    expect(workflow, contains('flutter build web'));
    expect(workflow, contains('actions/upload-artifact@v4'));
  });
}
