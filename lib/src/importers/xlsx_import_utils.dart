import 'dart:io';

import 'package:excel/excel.dart';

class XlsxImportUtils {
  static Excel loadWorkbook(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('File not found: $path');
    }

    return Excel.decodeBytes(file.readAsBytesSync());
  }

  // Excel cells can surface as different value classes. Importers use this
  // helper so sheet parsing code stays readable and source-focused.
  static String cellAsString(Data? cell) {
    final value = cell?.value;
    final resolved = switch (value) {
      null => '',
      TextCellValue() => value.value.text ?? '',
      FormulaCellValue() => value.formula,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value.toString(),
      DateCellValue() => '${value.year}-${value.month}-${value.day}',
      DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
      TimeCellValue() => value.asDuration().toString(),
    };
    return resolved.trim();
  }

  static double? parseNumeric(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('\u00A0', ' ')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('≤', '')
        .replaceAll('≥', '');
    if (normalized.isEmpty) {
      return null;
    }

    final traceNormalized = normalized
        .replaceAll(RegExp('traces?', caseSensitive: false), '0')
        .replaceAll('Tr', '0')
        .replaceAll('tr', '0');
    var sanitized = traceNormalized
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('*', '')
        .replaceAll(' ', '');
    if (sanitized.contains(',') && !sanitized.contains('.')) {
      sanitized = sanitized.replaceAll(',', '.');
    } else {
      sanitized = sanitized.replaceAll(',', '');
    }
    if (sanitized.isEmpty) {
      return null;
    }

    return double.tryParse(sanitized);
  }
}
