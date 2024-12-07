import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/serial_model.dart';

class DialUi extends StatefulWidget {
  const DialUi({super.key});

  @override
  State<DialUi> createState() => _DialUiState();
}

class _DialUiState extends State<DialUi> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Consumer<SerialModel>(builder: (context, serial, child) {
      return 
        Material(
          type: MaterialType.transparency,
          child: ListView(
            // controller: yourScrollController,
            children: [
              _tile('Model', serial.dialData.modelName),
              _tile('Gyro X', serial.dialData.gyroX.value.toStringAsFixed(1)),
              _tile('Gyro Y', serial.dialData.gyroY.value.toStringAsFixed(1)),
              _tile(
                  'Gyro Rad', serial.dialData.gyroRad.value.toStringAsFixed(1)),
              _tile(
                  'Planar X', serial.dialData.planarX.value.toStringAsFixed(1)),
              _tile(
                  'Planar Y', serial.dialData.planarY.value.toStringAsFixed(1)),
              _tile('Knob 1', serial.dialData.knob1.value.toStringAsFixed(0)),
              _tile('Knob 2', serial.dialData.knob2.value.toStringAsFixed(0)),
              _tile('Buttons', ''),
            ],
          ),
        );
    });
  }
}

ListTile _tile(String tileTitle, String value) {
  return ListTile(
    title: Text(value,
        style: const TextStyle(
          fontWeight: FontWeight.w300,
          fontSize: 20,
        )),
    subtitle: Text(tileTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w200,
          fontSize: 14,
        )),
  );
}
