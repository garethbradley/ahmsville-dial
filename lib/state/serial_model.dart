import 'dart:isolate';

import 'package:ahmsville_dial/isolates/serial_isolate_message.dart';
import 'package:ahmsville_dial/logger.dart';
import 'package:ahmsville_dial/models/dial_model.dart';
import 'package:ahmsville_dial/serial_state.dart';
import 'package:flutter/foundation.dart';

class SerialModel extends ChangeNotifier {
  String currentAddress = '';
  SerialState currentSerialState = SerialState.disconnected;
  SendPort? sendPort;
  DialModel dialData = DialModel();

  void connect(String address) {
    if (sendPort == null) return;

    sendPort!.send(
        SerialIsolateMessage(SerialIsolateMessageCommand.connect, address));
  }

  void disconnect() {
    if (sendPort == null) return;

    sendPort!
        .send(SerialIsolateMessage(SerialIsolateMessageCommand.disconnect, ""));
  }

  void setCurrentAddress(String address) {
    currentAddress = address;

    notifyListeners();
  }

  void setSerialState(SerialState newSerialState) {
    logPrint('📚 SetSerialState: ${newSerialState.name}');
    currentSerialState = newSerialState;

    notifyListeners();
  }

  void updateDialData(DialModel data) {
    dialData = data;

    notifyListeners();
  }
}
