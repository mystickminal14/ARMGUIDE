import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;

class MountainOverlay extends StatefulWidget {
  const MountainOverlay({super.key});
  @override
  State<MountainOverlay> createState() => _MountainOverlayState();
}

class _MountainOverlayState extends State<MountainOverlay> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  double _azimuth = 0.0;
  double _pitch = 0.0;
  double _lat = 0.0;
  double _lon = 0.0;
  double _altitude = 0.0;
  double _sunAngle = 0.0;
  String _locationName = "Locating...";
  late StreamSubscription _sensorSubscription;
  List<Map<String, dynamic>> _visibleMountains = [];
  List<double> _elevationProfile = [];
  final Map<String, List<double>> _elevationCache = {};
  bool _isDaytime = true;

  final List<Map<String, dynamic>> mountains = [
    {"name": "Everest", "lat": 27.9881, "lon": 86.9250, "ele": 8848.86},
    {"name": "Kanchenjunga", "lat": 27.7029, "lon": 88.1467, "ele": 8586},
    {"name": "Lhotse", "lat": 27.9616, "lon": 86.9333, "ele": 8516},
    {"name": "Makalu", "lat": 27.8897, "lon": 87.0888, "ele": 8485},
    {"name": "Cho Oyu", "lat": 28.0942, "lon": 86.6607, "ele": 8188},
    {"name": "Dhaulagiri I", "lat": 28.6967, "lon": 83.4875, "ele": 8167},
    {"name": "Manaslu", "lat": 28.5494, "lon": 84.5597, "ele": 8163},
    {"name": "Annapurna I", "lat": 28.5961, "lon": 83.8203, "ele": 8091},
    {"name": "Machhapuchhre", "lat": 28.4958, "lon": 83.9492, "ele": 6993},
    {"name": "Champa Devi", "lat": 27.6535, "lon": 85.2655, "ele": 2241},
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await _cameraController.initialize();
      setState(() => _isCameraInitialized = true);

      final pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lon = pos.longitude;
      _altitude = pos.altitude;
      _getPlaceName();
      _calculateSunAngle();

      _sensorSubscription = accelerometerEvents.listen((event) {
        _pitch = math.atan2(-event.x, math.sqrt(event.y * event.y + event.z * event.z));
      });

      magnetometerEvents.listen((event) {
        _azimuth = (math.atan2(event.y, event.x) * (180 / math.pi) + 360) % 360;
        _updateMountains();
        _fetchElevationProfile();
      });
    } catch (_) {
      setState(() => _locationName = "Sensor or camera error");
    }
  }

  Future<void> _getPlaceName() async {
    try {
      final placemarks = await placemarkFromCoordinates(_lat, _lon);
      final place = placemarks.first;
      setState(() {
        _locationName = place.locality ?? place.administrativeArea ?? "Unknown";
      });
    } catch (_) {
      setState(() => _locationName = "Unknown");
    }
  }

  void _calculateSunAngle() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45)); // Nepal time
    final hourAngle = (now.hour + now.minute / 60.0 - 12) * 15;
    _sunAngle = (90 - (math.cos(_degToRad(hourAngle)) * 90)).clamp(0, 90);
    setState(() {
      _isDaytime = now.hour >= 6 && now.hour < 18;
    });
  }

  void _updateMountains() {
    const fov = 60.0;
    final visible = <Map<String, dynamic>>[];
    for (var m in mountains) {
      final bearing = _calculateBearing(_lat, _lon, m['lat'], m['lon']);
      double relativeBearing = (bearing - _azimuth + 540) % 360 - 180;
      if (relativeBearing.abs() < fov / 2 && _pitch < 0.6) {
        final distance = _calculateDistance(_lat, _lon, m['lat'], m['lon']);
        visible.add({"name": m['name'], "bearing": bearing, "distance": distance, "rel": relativeBearing});
      }
    }
    visible.sort((a, b) => a['distance'].compareTo(b['distance']));
    setState(() => _visibleMountains = visible);
  }

  Future<void> _fetchElevationProfile() async {
    const samples = 100;
    final key = "${_lat.toStringAsFixed(3)}_${_lon.toStringAsFixed(3)}_${_azimuth.toStringAsFixed(1)}";
    if (_elevationCache.containsKey(key)) {
      setState(() => _elevationProfile = _elevationCache[key]!);
      return;
    }

    List<String> points = [];
    const radius = 0.02;
    const step = 60.0 / samples;
    for (int i = 0; i < samples; i++) {
      double bearing = (_azimuth - 30 + i * step + 360) % 360;
      double rad = bearing * math.pi / 180;
      double dLat = radius * math.cos(rad);
      double dLon = radius * math.sin(rad);
      double lat = _lat + dLat;
      double lon = _lon + dLon;
      points.add('$lat,$lon');
    }

    final url = Uri.parse('https://api.opentopodata.org/v1/srtm90m?locations=${points.join('|')}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body)['results'] as List;
        final elevations = results.map((e) => (e['elevation'] as num).toDouble()).toList();
        _elevationCache[key] = elevations;
        setState(() => _elevationProfile = elevations);
      }
    } catch (_) {
      setState(() => _elevationProfile = List.filled(samples, 0.0));
    }
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _degToRad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_degToRad(lat2));
    final x = math.cos(_degToRad(lat1)) * math.sin(_degToRad(lat2)) -
        math.sin(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * math.pi / 180;

  @override
  void dispose() {
    _cameraController.dispose();
    _sensorSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    final maxElevation = _elevationProfile.isNotEmpty ? _elevationProfile.reduce(math.max) : 1;
    final minElevation = _elevationProfile.isNotEmpty ? _elevationProfile.reduce(math.min) : 0;
    final scale = screen.height * 0.2 / (maxElevation - minElevation);
    final midY = screen.height * 0.5;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized)
            CameraPreview(_cameraController)
          else
            const Center(child: CircularProgressIndicator()),

          CustomPaint(
            size: screen,
            painter: TerrainPainter(
              elevationProfile: _elevationProfile,
              sunAngle: _sunAngle,
            ),
          ),

          // Mountain labels above terrain
          ..._visibleMountains.map((m) {
            double rel = m['rel'];
            double x = ((rel + 30) / 60) * screen.width;

            int index = ((rel + 30) / 60 * (_elevationProfile.length - 1)).round();
            index = index.clamp(0, _elevationProfile.length - 1);
            double elevation = _elevationProfile.isNotEmpty ? _elevationProfile[index] : 0;
            double y = midY - (elevation - minElevation) * scale - 40;

            return Positioned(
              left: x.clamp(0, screen.width - 100),
              top: y.clamp(0, screen.height - 100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  "${m['name']}\n${m['distance'].toStringAsFixed(1)} km",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            );
          }),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.explore, color: Colors.white),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_locationName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text("Alt: ${_altitude.toStringAsFixed(0)} m  Sun: ${_sunAngle.toStringAsFixed(1)}°",
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Text("${_lat.toStringAsFixed(3)}, ${_lon.toStringAsFixed(3)}",
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: Icon(
              _isDaytime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: Colors.yellowAccent,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class TerrainPainter extends CustomPainter {
  final List<double> elevationProfile;
  final double sunAngle;

  TerrainPainter({
    required this.elevationProfile,
    required this.sunAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevationProfile.isEmpty) return;

    final path = Path();
    final maxElevation = elevationProfile.reduce(math.max);
    final minElevation = elevationProfile.reduce(math.min);
    final midY = size.height * 0.5;
    final scale = size.height * 0.2 / (maxElevation - minElevation);

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < elevationProfile.length; i++) {
      final x = i / (elevationProfile.length - 1) * size.width;
      final y = midY - (elevationProfile[i] - minElevation) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final sunX = size.width / 2;
    final sunY = midY - (sunAngle / 90.0) * size.height * 0.4;
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.yellowAccent, Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: 30));

    canvas.drawCircle(Offset(sunX, sunY), 30, sunPaint);
    canvas.drawCircle(Offset(sunX, sunY), 5, Paint()..color = Colors.yellowAccent);
  }

  @override
  bool shouldRepaint(covariant TerrainPainter oldDelegate) => true;
}