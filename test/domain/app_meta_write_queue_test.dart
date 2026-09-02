import 'dart:async';

import 'package:data_hook_claws/src/domain/app_meta_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes writes per key and preserves invocation order', () async {
    final calls = <String>[];
    final firstRelease = Completer<void>();
    final queue = AppMetaWriteQueue((key, value) async {
      calls.add('$key:$value');
      if (value == 'first') {
        await firstRelease.future;
      }
    });

    final first = queue.enqueue('same', 'first');
    final second = queue.enqueue('same', 'second');
    final independent = queue.enqueue('other', 'independent');
    await independent;
    expect(calls, ['same:first', 'other:independent']);

    firstRelease.complete();
    await Future.wait([first, second]);
    expect(calls, ['same:first', 'other:independent', 'same:second']);
  });

  test('a failed write does not poison later writes for that key', () async {
    var shouldFail = true;
    final calls = <String>[];
    final queue = AppMetaWriteQueue((key, value) async {
      calls.add(value);
      if (shouldFail) {
        shouldFail = false;
        throw StateError('simulated metadata failure');
      }
    });

    await expectLater(queue.enqueue('same', 'failed'), throwsStateError);
    await queue.enqueue('same', 'recovered');

    expect(calls, ['failed', 'recovered']);
  });

  test(
    'releases completed key tails without disturbing an active write',
    () async {
      final activeRelease = Completer<void>();
      final queue = AppMetaWriteQueue((key, value) async {
        if (key == 'active') {
          await activeRelease.future;
        }
      });

      final active = queue.enqueue('active', 'first');
      final completed = queue.enqueue('completed', 'only');
      await completed;
      await Future<void>.delayed(Duration.zero);

      expect(queue.debugTrackedKeyCount, 1);

      activeRelease.complete();
      await active;
      await Future<void>.delayed(Duration.zero);

      expect(queue.debugTrackedKeyCount, 0);
    },
  );

  test(
    'releases failed key tails after preserving the error for the caller',
    () async {
      final queue = AppMetaWriteQueue((key, value) async {
        throw StateError('metadata write failed');
      });

      await expectLater(queue.enqueue('failed', 'value'), throwsStateError);
      await Future<void>.delayed(Duration.zero);

      expect(queue.debugTrackedKeyCount, 0);
    },
  );
}
