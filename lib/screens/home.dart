import 'package:ahmsville_dial/screens/home/dial_ui.dart';
import 'package:ahmsville_dial/screens/home/serial_list.dart';
import 'package:ahmsville_dial/widgets/joystick.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/serial_model.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final yourScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      // resizeToAvoidBottomInset: true,
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.primary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: <Widget>[
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(10.0),
            width: double.infinity,
            height: double.infinity,
            color: Theme.of(context).colorScheme.secondary,
            child: Column(children: [
              const SerialList(),
              Consumer<SerialModel>(builder: (context, serial, child) {
                JoystickData data = JoystickData();
                data.x = serial.dialData.planarX.value;
                data.y = serial.dialData.planarY.value;
                data.rotationX = serial.dialData.gyroX.value;
                data.rotationY = serial.dialData.gyroY.value;
                data.knob1 = serial.dialData.knob1.value;
                data.knob2 = serial.dialData.knob2.value;
                data.deadband = serial.dialData.planarDeadbandPercent;

                return Joystick(data: data);
              })
            ]),
          )),
          Expanded(
            child: Container(
                padding: const EdgeInsets.all(10.0),
                width: double.infinity,
                height: double.infinity,
                child: const DialUi()),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: initPorts,
      //   child: const Icon(Icons.refresh),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
