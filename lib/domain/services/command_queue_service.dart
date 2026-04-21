import 'dart:async';
import 'dart:collection';

/// Enforces sequential command execution.
/// QCBandSDK requires commands to be sent one at a time;
/// sending concurrent commands causes later ones to fail.
class CommandQueueService {
  final _queue = Queue<_QueuedCommand>();
  bool _processing = false;

  Future<T> enqueue<T>(Future<T> Function() command) {
    final completer = Completer<T>();
    _queue.add(_QueuedCommand(
      execute: () async => await command(),
      completer: completer,
    ));
    _processNext();
    return completer.future;
  }

  Future<void> _processNext() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final cmd = _queue.removeFirst();
      try {
        final result = await cmd.execute().timeout(
              const Duration(seconds: 10),
            );
        cmd.completer.complete(result);
      } on TimeoutException {
        cmd.completer.completeError(
          TimeoutException('Command timed out after 10s'),
        );
      } catch (e) {
        cmd.completer.completeError(e);
      }
    }

    _processing = false;
  }

  void clear() {
    for (final cmd in _queue) {
      cmd.completer.completeError(StateError('Queue cleared'));
    }
    _queue.clear();
  }
}

class _QueuedCommand {
  final Future<dynamic> Function() execute;
  final Completer<dynamic> completer;

  _QueuedCommand({required this.execute, required this.completer});
}
