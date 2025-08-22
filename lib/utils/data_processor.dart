import 'dart:async';
import 'dart:isolate';

class DataProcessor {
  static Future<void> processInIsolate({
    required List<dynamic> data,
    required Function processorFunction,
  }) async {
    final completer = Completer<void>();
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _isolateEntry,
      _IsolateData(
        receivePort.sendPort,
        data,
        processorFunction,
      ),
    );

    receivePort.listen((message) {
      if (message is _IsolateResult) {
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete();
        }
        receivePort.close();
      }
    });

    return completer.future;
  }

  static void _isolateEntry(_IsolateData data) {
    try {
      for (var item in data.inputData) {
        data.processorFunction(item);
      }
      data.sendPort.send(_IsolateResult(null));
    } catch (e) {
      data.sendPort.send(_IsolateResult(e));
    }
  }
}

class _IsolateData {
  final SendPort sendPort;
  final List<dynamic> inputData;
  final Function processorFunction;

  _IsolateData(this.sendPort, this.inputData, this.processorFunction);
}

class _IsolateResult {
  final dynamic error;
  _IsolateResult(this.error);
}