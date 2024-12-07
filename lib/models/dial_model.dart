import 'dart:math';
import 'package:ahmsville_dial/joystick_axis.dart';
import 'package:ahmsville_dial/logger.dart';
import 'package:ahmsville_dial/moving_average_double.dart';

enum DialType {
  unknown,
  baseVariant,
  macroKeyVariant,
  spaceNavVariant,
  absoluteVariant,
  baseVariantWireless,
  macroKeyVariantWireless,
  spaceNavVariantWireless,
  absoluteVariantWireless
}

enum DialButtons {
  macroButton1,
  macroButton2,
  macroButton3,
  macroButton4,
  macroButton5,
  touchPad
}

enum ButtonPressType { shortPress, longPress }

class ButtonPressEvent {
  ButtonPressEvent(this.button);

  DialButtons button;
  DateTime timestamp = DateTime.now();
  ButtonPressType pressType = ButtonPressType.shortPress;
}

class DialModel {
  double planarDeadbandPercent = 0.20;
  double gyroDeadbandPercent = 0.20;
  double planarXmax = 100;
  double planarXmin = -100;
  double planarYmax = 100;
  double planarYmin = -100;
  double gyroXmax = 100;
  double gyroXmin = -100;
  double gyroYmax = 100;
  double gyroYmin = -100;

  DialType model = DialType.unknown;

  MovingAverageDart gyroX = MovingAverageDart();
  MovingAverageDart gyroY = MovingAverageDart();
  MovingAverageDart gyroRad = MovingAverageDart();

  // MovingAverageDart planarX = MovingAverageDart(smoothingRange: 3);
  // MovingAverageDart planarY = MovingAverageDart(smoothingRange: 3);
  JoystickAxis planarX = JoystickAxis(axisTitle: "Planar X", allowLogging: false);
  JoystickAxis planarY = JoystickAxis(axisTitle: "Planar Y", allowLogging: false);

  MovingAverageDart knob2 =
      MovingAverageDart(smoothingRange: 5, sensitivityDelta: 1);
  MovingAverageDart knob1 =
      MovingAverageDart(smoothingRange: 1, sensitivityDelta: 1);

  final int _knob1Max = 8000;

  List<ButtonPressEvent> buttonEvents = [];

  bool button1Pressed = false;
  bool button2Pressed = false;
  bool button3Pressed = false;
  bool button4Pressed = false;
  bool button5Pressed = false;

  bool touchpadPressed = false;

  void parseMessage(String message) {
    try {
      if (message.startsWith('*')) {
        // Model variant

        message = message.replaceAll('*', '');
        // logPrint('🐝 DialModel - Model Variant: $message');

        if (message == '|||1|0|0|0|') {
          model = DialType.baseVariantWireless;
        } else if (message == '|||0|1|0|0|') {
          model = DialType.macroKeyVariantWireless;
        } else if (message == '|||0|0|1|0|') {
          model = DialType.spaceNavVariantWireless;
        } else if (message == '|||0|0|0|1|') {
          model = DialType.absoluteVariantWireless;
        } else {
          model = _getDialTypeFromMessage(message);
        }
      } else if (message.startsWith('<')) {
        // Gyro data

        message = message.replaceAll('<', '');
        List<String> stringArray = message.split('|');
        stringArray.removeWhere((element) => element.isEmpty);
        List<double> doubleArray = stringArray.map(double.parse).toList();

        if (doubleArray.length != 3) return;

        gyroX.value = _deadbandCalc(
            doubleArray[0], gyroXmin, gyroXmax, gyroDeadbandPercent);
        gyroY.value = _deadbandCalc(
            doubleArray[1], gyroYmin, gyroYmax, gyroDeadbandPercent);
        gyroRad.value = doubleArray[2];
      } else if (message.startsWith('>')) {
        // Planar data

        message = message.replaceAll('>', '');
        List<String> stringArray = message.split('|');
        stringArray.removeWhere((element) => element.isEmpty);
        List<double> doubleArray = stringArray.map(double.parse).toList();

        // logPrint('🐝 DialModel - Planar: $doubleArray, $message');

        if (doubleArray.length != 3) return;

        if (doubleArray[0].abs() < (planarXmax * planarDeadbandPercent)) {}

        // planarX.value = _deadbandCalc(
        //     doubleArray[0], planarXmin, planarXmax, planarDeadbandPercent);

        // planarY.value = _deadbandCalc(
        //     doubleArray[1], planarYmin, planarYmax, planarDeadbandPercent);
        planarX.value = doubleArray[0];
        planarY.value = doubleArray[1];

        knob2.value = doubleArray[2];
      } else if (message.startsWith('the app is in charge of ths')) {
        // Button data

        message = message.replaceAll('the app is in charge of ths', '');
        int buttonCmd = int.parse(message);

        switch (buttonCmd) {
          case 2:
            // Increase knob 1
            knob1.value = knob1.value + 1;
            while (knob1.value >= _knob1Max) {
              knob1.value -= _knob1Max;
            }
            break;

          case 3:
            // Decrease knob 1
            knob1.value = knob1.value - 1;
            while (knob1.value < 0) {
              knob1.value += _knob1Max;
            }
            break;

          case 10:
            // Macro Button 1
            buttonEvents.add(ButtonPressEvent(DialButtons.macroButton1));
            break;

          case 13:
            // Macro Button 2
            buttonEvents.add(ButtonPressEvent(DialButtons.macroButton2));
            break;

          case 19:
            // Macro Button 4
            buttonEvents.add(ButtonPressEvent(DialButtons.macroButton4));
            break;

          case 22:
            // Macro Button 5
            buttonEvents.add(ButtonPressEvent(DialButtons.macroButton5));
            break;

          default:
            logPrint('🐝 DialModel - Unknown Button: $buttonCmd');
            break;
        }
      } else {
        logPrint('🐝 DialModel - parseMessage: $message');
      }
    } catch (e) {
      logPrint('🐝 DialModel - parseMessage: Ignoring dodgy data');
    }
  }

  double _deadbandCalc(
      double value, double minValue, double maxValue, double deadbandPercent) {
    double range = maxValue - minValue;
    double rangeMidpoint = range / 2;
    double deadbandRange = range * deadbandPercent;
    double deadbandUpper = rangeMidpoint + (deadbandRange / 2);
    double deadbandLower = rangeMidpoint - (deadbandRange / 2);

    double absoluteValue = value - minValue;

    if (absoluteValue >= deadbandLower && absoluteValue <= deadbandUpper) {
      return 0;
    }

    double expoAmount = 5;
    double maxExpo = 5;
    double a2 = (expoAmount / 100.0 * maxExpo);
    double scalingFactor = 2.0 / exp(a2);
    double x = (((value - minValue) / (range) - 0.5) * 2);
    x = x < 0 ? x + deadbandPercent : x - deadbandPercent;

    double y = (x * exp((a2 * x).abs()) * scalingFactor);

    return (y * (range / 2));
  }

  bool get isDirty {
    bool dirty = false;

    dirty = dirty || gyroX.isDirty;
    dirty = dirty || gyroY.isDirty;
    dirty = dirty || gyroRad.isDirty;
    dirty = dirty || planarX.isDirty;
    dirty = dirty || planarY.isDirty;
    dirty = dirty || knob1.isDirty;
    dirty = dirty || knob2.isDirty;
    dirty = dirty || buttonEvents.isNotEmpty;

    return dirty;
  }

  String get modelName {
    switch (model) {
      case DialType.baseVariant:
        return 'Base Variant';
      case DialType.macroKeyVariant:
        return 'MacroKey Variant';
      case DialType.spaceNavVariant:
        return 'SpaceNav Variant';
      case DialType.absoluteVariant:
        return 'Absolute Variant';
      case DialType.baseVariantWireless:
        return 'Base Variant (Wireless)';
      case DialType.macroKeyVariantWireless:
        return 'MacroKey Variant (Wireless)';
      case DialType.spaceNavVariantWireless:
        return 'SpaceNav Variant (Wireless)';
      case DialType.absoluteVariantWireless:
        return 'Absolute Variant (Wireless)';
      default:
        return 'Unknown Model';
    }
  }

  DialType _getDialTypeFromMessage(String message) {
    switch (message) {
      case "Base Variant":
        return DialType.baseVariant;
      case "MacroKey Variant":
        return DialType.macroKeyVariant;
      case "SpaceNav Variant":
        return DialType.spaceNavVariant;
      case "Absolute Variant":
        return DialType.absoluteVariant;
      default:
        return DialType.unknown;
    }
  }

  @override
  String toString() {
    return '${gyroX.value.toStringAsFixed(3)}, ${gyroY.value.toStringAsFixed(3)}, ${gyroRad.value.toStringAsFixed(3)} - ${planarX.value.toStringAsFixed(3)}, ${planarY.value.toStringAsFixed(3)}, ${knob2.value.toStringAsFixed(3)}';
  }

  double _truncatePrecision(double value, {int decimalPlaces = 3}) {
    value *= pow(10, decimalPlaces);
    value = value.roundToDouble();
    value /= pow(10, decimalPlaces);

    return value;
  }

  void clearButtonEvents() {
    buttonEvents = [];
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> buttonEventsJson = [];

    for (ButtonPressEvent event in buttonEvents) {
      buttonEventsJson.add({
        'type': 'event',
        'button': event.button.toString(),
        'pressType': event.pressType.toString(),
        'timestamp': event.timestamp.millisecondsSinceEpoch,
      });
    }
    
    Map<String, dynamic> jsonObj = {
      'type': 'gyro',
      'gyroX': _truncatePrecision(gyroX.value),
      'gyroY': _truncatePrecision(gyroY.value),
      'gyroRad': _truncatePrecision(gyroRad.value),
      'planarX': _truncatePrecision(planarX.value),
      'planarY': _truncatePrecision(planarY.value),
      'knob1': _truncatePrecision(knob1.value),
      'knob2': _truncatePrecision(knob2.value),
      'buttonEvents': buttonEventsJson
    };

    return jsonObj;
  }
}
