import 'dart:isolate';
import 'package:ahmsville_dial/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/dial_model.dart';
import '../serial_state.dart';
import 'serial_isolate_message.dart';

// The entrypoint that runs on the spawned isolate. Receives messages from
// the main isolate, reads the contents of the file, decodes the JSON, and
// sends the result back to the main isolate.

Future<void> serialIsolate(SendPort p) async {
  logPrint('🐝 Spawned isolate started.');

  SerialPort? currentPort;
  String currentAddress = "";
  SerialState currentSerialState = SerialState.disconnected;
  SerialPortReader? reader;
  DialModel model = DialModel();

  // Send a SendPort to the main isolate so that it can send JSON strings to
  // this isolate.
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  // Wait for messages from the main isolate.
  await for (final command in commandPort) {
    if (command is SerialIsolateMessage) {
      logPrint(
          '🐝 Command received: ${command.command.name}, ${command.message}');

      switch (command.command) {
        case SerialIsolateMessageCommand.connect:
          try {
            if (currentAddress.isNotEmpty) {
              currentPort!.close();
            }
          } catch (e) {
            // Do nothing
          }

          try {
            currentAddress = command.message;
            currentPort = SerialPort(currentAddress);
            final portconfig = SerialPortConfig();
            portconfig.baudRate = 115200;
            currentSerialState =
                setSerialState(p, SerialState.connecting, currentAddress);
            currentSerialState = setSerialState(
                p,
                currentPort.openReadWrite()
                    ? SerialState.connected
                    : SerialState.disconnected,
                currentAddress);

            if (currentPort.isOpen) {
              currentPort.config = portconfig;
              currentPort.write(convertStringToUint8List('4'));
              // await Future.delayed(const Duration(milliseconds: 500));
              currentPort.write(convertStringToUint8List('a'));

              reader = SerialPortReader(currentPort);
              Stream<String> upcomingData = reader.stream.map((data) {
                return String.fromCharCodes(data);
              });

              upcomingData.listen((event) {
                // print(event);
                while (event.length >= 30) {
                  String message = event.substring(0, 30);
                  model.parseMessage(message);

                  if (model.isDirty) {
                    p.send(SerialIsolateResponse.dataUpdate(data: model));

                    // We've sent it all out - reset the button press events for next round
                    model.clearButtonEvents();
                    // logPrint('🐝 Data is dirty. Sending');
                  } 
                  // else {
                  //   logPrint('🐝 Data not dirty. Ignoring');
                  // }

                  event = event.substring(30);
                }
              });
            }
          } catch (e) {
            // Do nothing
          }

          break;

        case SerialIsolateMessageCommand.disconnect:
          try {
            reader!.close();
          } catch (e) {
            // Do nothing
          }

          try {
            currentPort!.close();
          } catch (e) {
            // Do nothing
          }

          currentAddress = '';
          currentSerialState =
              setSerialState(p, SerialState.disconnected, currentAddress);

          /// Clear Dial Model and send update to reset
          model = DialModel();
          p.send(SerialIsolateResponse.dataUpdate(data: model));

          break;

        case SerialIsolateMessageCommand.getStatus:
          p.send(SerialIsolateResponse(
              SerialIsolateResponseType.status, currentSerialState.toString()));
          break;

        default:
          break;
      }
      // Send the result to the main isolate.
      // p.send(jsonDecode(contents));
    } else if (command == null) {
      // Exit if the main isolate sends a null message, indicating there are no
      // more files to read and parse.
      break;
    }
  }

  logPrint('🐝 Spawned isolate finished.');
  Isolate.exit();
}

SerialState setSerialState(
    SendPort p, SerialState newSerialState, String address) {
  logPrint('🐝 SetSerialState: ${newSerialState.toString()}');

  p.send(SerialIsolateResponse.withAddress(
      SerialIsolateResponseType.status, newSerialState.name, address));

  return newSerialState;
}

Uint8List convertStringToUint8List(String str) {
  final List<int> codeUnits = str.codeUnits;
  final Uint8List unit8List = Uint8List.fromList(codeUnits);

  return unit8List;
}
