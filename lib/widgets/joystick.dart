import 'dart:math';

import 'package:flutter/material.dart';

class JoystickData {
  double minX = -100;
  double maxX = 100;
  double x = 0;

  double minY = -100;
  double maxY = 100;
  double y = 0;

  double minRotationX = -100;
  double maxRotationX = 100;
  double rotationX = 0;

  double minRotationY = -100;
  double maxRotationY = 100;
  double rotationY = 0;

  double knob1StepsPerRotation = 240;
  double knob1 = 0;

  double knob2StepsPerRotation = 5000;
  double knob2 = 0;

  // Deadband in percent (0-1)
  double deadband = 0.15;
}

class Joystick extends StatelessWidget {
  final JoystickData data;

  final double size = 300;
  final double dotSize = 30;

  const Joystick({super.key, required this.data});

  List<double> getCoordinates() {
    List<double> xy = [size / 2, size / 2];

    double rangeX = (data.maxX - data.minX);
    double clamppedXPercent = max(min((data.x - data.minX) / rangeX, 1), 0);
    xy[0] = (clamppedXPercent * size);

    double rangeY = (data.maxY - data.minY);
    double clamppedYPercent = max(min((data.y - data.minY) / rangeY, 1), 0);
    xy[1] = size - (clamppedYPercent * size);

    // print('X: ${data.x.toStringAsFixed(1)}, %: ${clamppedXPercent.toStringAsFixed(3)}, Range: $rangeX, resulting in ${xy[0]}');

    xy[0] -= dotSize / 2;
    xy[1] -= dotSize / 2;

    return xy;
  }

  List<double> getRotation() {
    List<double> xy = [0, 0];

    double rangeX = (data.maxRotationX - data.minRotationX);
    double clamppedXPercent =
        max(min((data.rotationX - data.minRotationX) / rangeX, 1), 0);
    xy[1] = (clamppedXPercent * pi) + (pi / 2);

    double rangeY = (data.maxRotationY - data.minRotationY);
    double clamppedYPercent =
        1 - max(min((data.rotationY - data.minRotationY) / rangeY, 1), 0);
    xy[0] = (clamppedYPercent * pi) + (pi / 2);

    // print('X: ${data.x.toStringAsFixed(1)}, %: ${clamppedXPercent.toStringAsFixed(3)}, Range: $rangeX, resulting in ${xy[0]}');

    return xy;
  }

  List<double> getKnobsAngle() {
    List<double> k12 = [0, 0];
    double currentK1 = data.knob1;
    double currentK2 = data.knob2;

    while (currentK1 >= data.knob1StepsPerRotation) {
      currentK1 -= data.knob1StepsPerRotation;
    }

    double anglePerStepKnob1 = (2 * pi) / data.knob1StepsPerRotation;
    k12[0] = max(min(currentK1 * anglePerStepKnob1, 2 * pi), 0);

    while (currentK2 >= data.knob2StepsPerRotation) {
      currentK2 -= data.knob2StepsPerRotation;
    }

    double anglePerStepKnob2 = (2 * pi) / data.knob2StepsPerRotation;
    k12[1] = max(min(currentK2 * anglePerStepKnob2, 2 * pi), 0);

    return k12;
  }

  @override
  Widget build(BuildContext context) {
    List<double> xy = getCoordinates();
    List<double> rotationXY = getRotation();
    List<double> k12 = getKnobsAngle();

    return Stack(children: [
      Container(
        width: size,
        height: size,
        decoration:
            const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
      ),
      Positioned(
        top: (size / 2) - ((size * data.deadband) / 2),
        left: (size / 2) - ((size * data.deadband) / 2),
        child: Container(
          width: size * data.deadband,
          height: size * data.deadband,
          decoration:
              const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
        ),
      ),
      Positioned(
        top: 0,
        left: (size / 2) - 1,
        child: Container(
          width: 2.0,
          height: size,
          decoration: const BoxDecoration(
              color: Color.fromARGB(255, 175, 110, 186),
              shape: BoxShape.rectangle),
        ),
      ),
      Positioned(
        top: (size / 2) - 1,
        left: 0,
        child: Container(
          width: size,
          height: 2.0,
          decoration: const BoxDecoration(
              color: Color.fromARGB(255, 175, 110, 186),
              shape: BoxShape.rectangle),
        ),
      ),
      Positioned(
        left: (size / 2) - 3,
        top: 0,
        child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateZ(k12[0]),
            origin: Offset(3, size / 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 6,
                  height: 20,
                  decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 109, 236, 87),
                      shape: BoxShape.rectangle),
                ),
              ],
            )),
      ),
      Positioned(
        left: (size / 2) - 3,
        top: 0,
        child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateZ(k12[1]),
            origin: Offset(3, size / 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 6,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 80, 100, 229),
                      shape: BoxShape.rectangle),
                ),
              ],
            )),
      ),
      Positioned(
        left: xy[0],
        top: xy[1],
        child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(rotationXY[0])
              ..rotateY(rotationXY[1]),
            alignment: FractionalOffset.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                      color: Colors.purple, shape: BoxShape.circle),
                ),
                Container(
                  width: dotSize / 3,
                  height: dotSize / 3,
                  decoration: const BoxDecoration(
                      color: Colors.black, shape: BoxShape.circle),
                ),
                Positioned(
                  bottom: -(dotSize / 10),
                  left: (dotSize / 2) - (dotSize / 10),
                  child: Container(
                    width: dotSize / 5,
                    height: dotSize / 5,
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  bottom: (dotSize / 2) - (dotSize / 10),
                  left: -(dotSize / 10),
                  child: Container(
                    width: dotSize / 5,
                    height: dotSize / 5,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  top: -(dotSize / 10),
                  left: (dotSize / 2) - (dotSize / 10),
                  child: Container(
                    width: dotSize / 5,
                    height: dotSize / 5,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  bottom: (dotSize / 2) - (dotSize / 10),
                  right: -(dotSize / 10),
                  child: Container(
                    width: dotSize / 5,
                    height: dotSize / 5,
                    decoration: const BoxDecoration(
                        color: Colors.yellow, shape: BoxShape.circle),
                  ),
                )
              ],
            )),
      )
    ]);
  }
}
