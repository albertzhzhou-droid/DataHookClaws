import 'package:data_hook_claws/src/domain/app_meta_payload_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measures app_meta payloads in UTF-8 bytes', () {
    const ascii = 'plain app metadata';
    const multibyte = '😀配置';

    expect(AppMetaPayloadBudget.utf8ByteLength(ascii), ascii.length);
    expect(
      AppMetaPayloadBudget.utf8ByteLength(multibyte),
      greaterThan(multibyte.length),
    );
  });
}
