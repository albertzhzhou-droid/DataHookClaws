import 'dart:convert';

class AppMetaPayloadBudget {
  const AppMetaPayloadBudget._();

  static int utf8ByteLength(String payload) => utf8.encode(payload).length;
}
