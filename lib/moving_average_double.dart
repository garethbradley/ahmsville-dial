import 'package:collection/collection.dart';

class MovingAverageDart {
  MovingAverageDart({this.smoothingRange = 25, this.sensitivityDelta = 0.1});

  List<double> values = [];
  double currentSmoothedValue = 0;
  int smoothingRange = 25;
  double sensitivityDelta = 0.1;

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

  double previousValue() {
    if (values.isEmpty) return 0;
    if (values.length == 1) return values.last;

    return values[values.length - 2];
  }
  
  bool get isDirty {
    return (lastValue() - previousValue()).abs() > sensitivityDelta;
  }

  set value(double newValue) {
    _updateValue(newValue);
  }

  double get value {
    return currentSmoothedValue;
  }
}