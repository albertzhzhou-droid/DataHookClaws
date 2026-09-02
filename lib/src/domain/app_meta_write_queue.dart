import 'dart:async';

class AppMetaWriteQueue {
  AppMetaWriteQueue(this._write);

  final Future<void> Function(String key, String value) _write;
  final Map<String, Future<void>> _tails = {};

  int get debugTrackedKeyCount => _tails.length;

  Future<void> enqueue(String key, String value) {
    final previous = _tails[key] ?? Future<void>.value();
    final operation = previous
        .catchError((_) {})
        .then((_) => _write(key, value));
    final settled = operation.catchError((_) {});
    _tails[key] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_tails[key], settled)) {
          _tails.remove(key);
        }
      }),
    );
    return operation;
  }
}
