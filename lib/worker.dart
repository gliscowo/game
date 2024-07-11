import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:meta/meta.dart';

class WorkerPool<I, O> {
  final List<WorkerIsolate<I, O>> _workers;
  int _taskCount = 0;

  WorkerPool._(this._workers);

  /// Create a new [WorkerPool] of size [size]
  ///
  /// Each worker is initialized after startup by executing
  /// [init], after which it will execute [task] for every
  /// command sent through [process]
  ///
  /// [nameFactory] is used to generate the [Isolate.debugName]
  /// for each worker from its index
  @factory
  static Future<WorkerPool<I, O>> create<I, O>(
    void Function() init,
    O Function(I) task,
    int size,
    String Function(int) nameFactory,
  ) async =>
      WorkerPool._(await Future.wait(List.generate(
        size,
        (idx) => WorkerIsolate.spawn<I, O>(init, task, nameFactory(idx)),
      )));

  /// How many commands this pool is currently processing
  int get taskCount => _taskCount;

  /// The amount of workers this pool currently uses
  int get size => _workers.length;

  Future<O> process(I command) {
    var workerWithLowestTaskCount = _workers.reduce((a, b) => a.pendingTasks < b.pendingTasks ? a : b);

    _taskCount++;
    return workerWithLowestTaskCount.process(command).whenComplete(() => _taskCount--);
  }

  void shutdown() {
    for (final worker in _workers) {
      worker.shutdown();
    }
  }
}

class WorkerIsolate<I, O> {
  final Queue<Completer<O>> _callbacks = Queue();
  final SendPort _commands;
  final ReceivePort _responses;
  final Isolate _isolate;

  WorkerIsolate._(this._commands, this._responses, this._isolate) {
    _responses.listen((result) {
      _callbacks.removeFirst().complete(result);
    });
  }

  static Future<WorkerIsolate<I, O>> spawn<I, O>(void Function() init, O Function(I) task, String name) async {
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((ReceivePort.fromRawReceivePort(initPort), commandPort));
    };

    final isolate = await Isolate.spawn(_worker(init, task), initPort.sendPort, debugName: name);
    final (responses, commands) = await connection.future;

    return WorkerIsolate._(commands, responses, isolate);
  }

  static void Function(SendPort) _worker<I, O>(void Function() init, O Function(I) task) => (responses) async {
        final commands = ReceivePort();
        responses.send(commands.sendPort);

        init();

        await for (final command in commands) {
          responses.send(task(command));
        }
      };

  int get pendingTasks => _callbacks.length;

  Future<O> process(I command) {
    _commands.send(command);

    var completer = Completer<O>();
    _callbacks.add(completer);
    return completer.future;
  }

  void shutdown() {
    _isolate.kill(priority: Isolate.immediate);
    _responses.close();
  }
}
