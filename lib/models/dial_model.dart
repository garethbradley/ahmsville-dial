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

class DialModel {
  DialType model = DialType.unknown;

  MovingAverageDart gyroX = MovingAverageDart();
  MovingAverageDart gyroY = MovingAverageDart();
  MovingAverageDart gyroRad = MovingAverageDart();

  MovingAverageDart planarX = MovingAverageDart(smoothingRange: 3);
  MovingAverageDart planarY = MovingAverageDart(smoothingRange: 3);
  MovingAverageDart knob2 = MovingAverageDart(smoothingRange: 5);
  int knob1 = 0;

  final int _knob1Max = 8000;

  bool button1Pressed = false;
  bool button2Pressed = false;
  bool button3Pressed = false;
  bool button4Pressed = false;
  bool button5Pressed = false;

  bool touchpadPressed = false;

  void parseMessage(String message) {
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

      gyroX.value = doubleArray[0];
      gyroY.value = doubleArray[1];
      gyroRad.value = doubleArray[2];
    } else if (message.startsWith('>')) {
      // Planar data

      message = message.replaceAll('>', '');
      List<String> stringArray = message.split('|');
      stringArray.removeWhere((element) => element.isEmpty);
      List<double> doubleArray = stringArray.map(double.parse).toList();

      // logPrint('🐝 DialModel - Planar: $doubleArray, $message');

      if (doubleArray.length != 3) return;

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
          knob1++;
          while (knob1 >= _knob1Max) {
            knob1 -= _knob1Max;
          }
          break;

        case 3:
          // Decrease knob 1
          knob1--;
          while (knob1 < 0) {
            knob1 += _knob1Max;
          }
          break;

        case 10:
          // Macro Button 1
          button1Pressed = true;
          break;

        case 13:
          // Macro Button 2
          button2Pressed = true;
          break;

        case 19:
          // Macro Button 4
          button4Pressed = true;
          break;

        case 22:
          // Macro Button 5
          button5Pressed = true;
          break;

        default:
          logPrint('🐝 DialModel - Unknown Button: $buttonCmd');
          break;
      }
    } else {
      logPrint('🐝 DialModel - parseMessage: $message');
    }
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
}
