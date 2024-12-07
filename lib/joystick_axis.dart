import 'dart:math';

class JoystickAxis {
  JoystickAxis({this.axisTitle = "", this.allowLogging = false});

  // Constants
  bool allowLogging = false;
  String axisTitle = "";

  static const double historyLength = 6; // How much history to keep to review divation
  static const double correctionZoneThresholdStart = 50; // Adjustment zone
  static const double correctionZoneThresholdEnd = 0.1; // Adjust as needed
  static const double trendFactor = 0.2; // Adjust as needed
  static const double stabilityThreshold = 0.1; // Adjust as needed
  static const double sensitivityDelta = 0.0;
  static const double deadzone = 0.5;

  // Variables
  double currentValue = 0.0;
  double currentCenterPoint = 0.0;
  List<double> valueHistory = [];

  // Function to update the joystick value
  void _updateJoystickValue(double newValue) {
    // Add the new value to the history
    valueHistory.add(newValue);

    // Trim the history to keep only the last n values (adjust n as needed)
    if (valueHistory.length > historyLength) {
      valueHistory.removeAt(0);
    }

    bool bInCorrectionZone = isInCorrectionZone(newValue, centerPoint);
    bool bIsStable = isStable();
    double deltaCorrection = 0.0;

    if (bInCorrectionZone && bIsStable) {
      // If near center and stable, trend towards 0
      // currentValue *= 1.0 - trendFactor;
      deltaCorrection = ((newValue - currentCenterPoint) * trendFactor);
      deltaCorrection = double.parse((deltaCorrection).toStringAsFixed(2));

      currentCenterPoint += deltaCorrection;
    } else {
      // Otherwise, update the value3
      deltaCorrection = 0.0;
    }

    if (newValue < 0 && newValue < currentCenterPoint) {
      currentCenterPoint = currentCenterPoint.clamp(-correctionZoneThresholdStart, 0);
    } else if (newValue > 0 && newValue > currentCenterPoint) {
      currentCenterPoint = currentCenterPoint.clamp(0, correctionZoneThresholdStart);
    }


    currentCenterPoint = double.parse((currentCenterPoint).toStringAsFixed(2));

    // Clamp the value to the -100 to 100 range
    
    currentValue = (newValue - currentCenterPoint).clamp(-100.0, 100.0);
    if (currentValue.abs() <= deadzone) currentValue = 0;

    currentValue = double.parse((currentValue).toStringAsFixed(2));
    // currentCenterPoint = newValue - currentValue;

    if (allowLogging) print("Joystick Axis: $value, Raw: $newValue, Center: $currentCenterPoint, Correction: $deltaCorrection ($bInCorrectionZone, $bIsStable)");
  }

  // Function to check if the value is near the center
  bool isInCorrectionZone(double value, double offset) {
    return ((value.abs()) < correctionZoneThresholdStart) && ((value.abs()) > correctionZoneThresholdEnd);
  }

  // Function to check if the value is relatively stable using standard deviation
  bool isStable() {
    if (valueHistory.length < 2) {
      // If there are not enough values for standard deviation, consider it stable
      return true;
    }

    // Calculate the standard deviation of the values in the history
    double mean = valueHistory.reduce((a, b) => a + b) / valueHistory.length;
    double variance = valueHistory
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        valueHistory.length;
    double stdDev = sqrt(variance);

    // Adjust the threshold based on your requirements
    return stdDev < stabilityThreshold;
  }

  double lastValue() {
    if (valueHistory.isEmpty) return 0;

    return valueHistory.last;
  }

  double previousValue() {
    if (valueHistory.isEmpty) return 0;
    if (valueHistory.length == 1) return valueHistory.last;

    return valueHistory[valueHistory.length - 2];
  }

  bool get isDirty {
    return (lastValue() - previousValue()).abs() > sensitivityDelta;
  }

  set value(double newValue) {
    _updateJoystickValue(newValue);
  }

  double get rawValue {
    if (valueHistory.isEmpty) return 0;

    return valueHistory.last;
  }

  double get centerPoint {
    return currentCenterPoint;
  }

  double get value {
    return currentValue;
  }

  // double get offset {
  //   return currentAxisOffset;
  // }
}
