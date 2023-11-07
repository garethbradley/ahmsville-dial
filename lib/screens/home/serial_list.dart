import 'package:ahmsville_dial/serial_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:provider/provider.dart';

import '../../state/serial_model.dart';

class SerialList extends StatefulWidget {
  const SerialList({super.key});

  @override
  State<SerialList> createState() => _SerialListState();
}

class _SerialListState extends State<SerialList> {
  var availablePorts = [];

  @override
  void initState() {
    super.initState();
    initPorts();
  }

  void initPorts() {
    setState(() => availablePorts = SerialPort.availablePorts);
  }

  Icon? getConnectionIcon(SerialModel serial, String address) {
    if (serial.currentAddress == address) {
      switch (serial.currentSerialState) {
        case SerialState.disconnected:
          return Icon(Icons.done, color: Colors.grey.shade300);
        case SerialState.connecting:
          return Icon(Icons.done_all, color: Colors.grey.shade300);
        case SerialState.connected:
          return const Icon(Icons.done_all, color: Colors.green);
      }
    }

    return null;
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
      return Material(
        type: MaterialType.transparency,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 50),
          // controller: yourScrollController,
          children: [
            for (final address in availablePorts)
              Builder(builder: (context) {
                final port = SerialPort(address);
                try {
                  if (port.vendorId == 0x2341) {
                    final String tileTitle =
                        address != null ? '$address' : 'N/A';
                    return ListTile(
                        title: Text(tileTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            )),
                        trailing: getConnectionIcon(serial, address),
                        textColor: Theme.of(context).colorScheme.surface,
                        tileColor: Colors.transparent,
                        hoverColor: Theme.of(context).colorScheme.primary,
                        selectedTileColor:
                            Theme.of(context).colorScheme.primary,
                        onTap: () {
                          String newAddress =
                              (serial.currentAddress == address) ? '' : address;

                          if (newAddress.isNotEmpty) {
                            serial.connect(newAddress);
                          } else {
                            serial.disconnect();
                          }
                        });
                  }
                } catch (e) {
                  return Container();
                }

                return Container();
              }),
          ],
        ),
      );
    });
  }
}
