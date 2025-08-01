import 'package:flutter/material.dart';
import '../model/mountain.dart';
class MountainDetailScreen extends StatelessWidget {
  final Mountain mountain;
  const MountainDetailScreen({super.key, required this.mountain});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mountain.name)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Latitude: ${mountain.latitude}"),
            Text("Longitude: ${mountain.longitude}"),
            Text("Elevation: ${mountain.elevation} m"),
            const SizedBox(height: 20),
            const Text("More information coming soon..."),
          ],
        ),
      ),
    );
  }
}
