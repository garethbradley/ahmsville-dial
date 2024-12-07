import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:ahmsville_dial/isolates/websocket_isolate_message.dart';
import 'package:ahmsville_dial/logger.dart';
import '../models/dial_model.dart';

// The entrypoint that runs on the spawned isolate. Receives messages from
// the main isolate, reads the contents of the file, decodes the JSON, and
// sends the result back to the main isolate.

Future<void> websocketIsolate(SendPort p) async {
  logPrint('💬 Spawned websocket isolate started.');

  DialModel model = DialModel();
  List<WebSocket> sockets = [];

  // Send a SendPort to the main isolate so that it can send JSON strings to
  // this isolate.
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  // Port 23425 - ADIAL on phone keypad
  HttpServer.bind("localhost", 23425).then((HttpServer wsServer) {
    logPrint('💬 Listening on ws://localhost:${wsServer.port}/ws');

    wsServer.listen((HttpRequest request) async {
      if (request.uri.path == '/ws') {
        // Upgrade an HttpRequest to a WebSocket connection
        var socket = await WebSocketTransformer.upgrade(request);
        // socket.pingInterval = const Duration(seconds: 10);
        logPrint('💬 Client connected!');

        socket.done.then((value) {
          if (value is WebSocket) {
            logPrint('💬 Client disconnected.');
            sockets.remove(value);
          }
        });

        sockets.add(socket);

        // // Listen for incoming messages from the client
        // socket.listen((message) {
        //   print('Received message: $message');
        //   socket.add('You sent: $message');
        // });
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
      }
    });
  });

  // Wait for messages from the main isolate.
  await for (final command in commandPort) {
    if (command is WebsocketIsolateMessage) {
      if (command.data != null) {
        model = command.data!;
        String message = jsonEncode(model);

        // Ensure we don't send out spent events again
        model.clearButtonEvents();
        
        // logPrint('💬 Data received: ${model.toString()}');

        for (WebSocket socket in sockets) {
          socket.add(message);
        }
      }

      // Send the result to the main isolate.
      // p.send(jsonDecode(contents));
    } else if (command == null) {
      // Exit if the main isolate sends a null message, indicating there are no
      // more files to read and parse.
      break;
    }
  }

  logPrint('💬 Spawned isolate finished.');
  Isolate.exit();
}
