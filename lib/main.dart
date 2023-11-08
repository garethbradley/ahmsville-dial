import 'dart:async';
import 'dart:isolate';

import 'package:ahmsville_dial/isolates/serial_isolate_message.dart';
import 'package:ahmsville_dial/logger.dart';
import 'package:ahmsville_dial/state/serial_model.dart';
import 'package:flutter/material.dart';
import 'package:dotup_flutter_active_window/dotup_flutter_active_window.dart';
import 'package:provider/provider.dart';

import './screens/home.dart';
import 'isolates/serial_isolate.dart';
import 'serial_state.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // await windowManager.ensureInitialized();

  // WindowOptions windowOptions = const WindowOptions(
  //     size: Size(800, 600),
  //     center: true,
  //     skipTaskbar: false,
  //     title: "Ahmsville Dial Controller");

  // windowManager.waitUntilReadyToShow(windowOptions, () async {
  //   await windowManager.show();
  //   await windowManager.focus();
  // });

  // or with observer
  // final filterFromDb = ActiveWindowFilter(value: 'dotup_', field: ActiveWindowProperty.title);
  final windowObserver = ActiveWindowObserver()
    // ..addFilter((windowInfo) => windowInfo?.title.contains('main') == false)
    // ..addFilter(ActiveWindowFilterGenerator().generate(filterFromDb))
    ..listen((event) {
      print(event);
    });
  windowObserver.start();

  SerialModel state = SerialModel();
  createIsolate(state);

  runApp(
    ChangeNotifierProvider(create: (context) => state, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ahmsville Dial Controller'),
    );
  }
}

Future createIsolate(SerialModel state) async {
  /// Where I listen to the message from Mike's port
  ReceivePort myReceivePort = ReceivePort();

  /// Spawn an isolate, passing my receivePort sendPort
  Isolate.spawn<SendPort>(serialIsolate, myReceivePort.sendPort);

  final completer = Completer<SendPort>(); // For awaiting the SendPort.
  myReceivePort.listen((message) {
    if (message is SendPort) {
      completer.complete(message);
    } else if (message is SerialIsolateResponse) {
      // logPrint('🏠 Isolate response: ${message.type.name}, ${message.message}');

      switch (message.type) {
        case SerialIsolateResponseType.status:
          SerialState newSerialState =
              SerialState.values.byName(message.message);

          state.setCurrentAddress(message.address!);
          state.setSerialState(newSerialState);

          break;

        case SerialIsolateResponseType.data:
          // logPrint('🏠 Data: ${message.data.toString()}');

          state.updateDialData(message.data!);

          break;
        default:
          break;
      }
    } else {
      logPrint('🏠 Unknown response: $message');
    }
  });
  final serialIsolateSendPort = await completer.future; // Get the SendPort.
  state.sendPort = serialIsolateSendPort;

  // Initiate the 2-way connection
  serialIsolateSendPort
      .send(SerialIsolateMessage(SerialIsolateMessageCommand.initiate, ''));
}
