import 'package:collection/collection.dart';

class MovingAverageDart {
  MovingAverageDart({this.smoothingRange = 25});

  List<double> values = [];
  double currentSmoothedValue = 0;
  int smoothingRange = 25;

  void _updateValue(newValue) {
    values.add(newValue);

    while (values.length > smoothingRange) {
      values.removeAt(0);
    }

    currentSmoothedValue = values.average;
  }

  double lastValue() {
    if (values.isEmpty) return 0;

    return values.last;
  }

  set value(double newValue) {
    _updateValue(newValue);
  }

  double get value {
    return currentSmoothedValue;
  }
}