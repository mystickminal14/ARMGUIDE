import 'dart:async';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static StreamSubscription? _accelSubscription;
  static StreamSubscription? _compassSubscription;

  static void startListening(void Function(double azimuth, double pitch) onData) {
    double? azimuth;
    double? pitch;

    _compassSubscription = FlutterCompass.events!.listen((event) {
      azimuth = event.heading;
      if (azimuth != null && pitch != null) {
        onData(azimuth!, pitch!);
      }
    });

    _accelSubscription = accelerometerEvents.listen((event) {
      pitch = atan2(-event.x, sqrt(event.y * event.y + event.z * event.z));
      if (azimuth != null && pitch != null) {
        onData(azimuth!, pitch!);
      }
    });
  }

  static void stopListening() {
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
  }
}
