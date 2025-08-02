import 'package:flutter/material.dart';

class IndoorScreen extends StatefulWidget {
  const IndoorScreen({super.key});

  @override
  State<IndoorScreen> createState() => _IndoorScreenState();
}

class _IndoorScreenState extends State<IndoorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Indoor Mode")),
      body: const Center(child: Text("This is the indoor mode view.")),
    );
  }
}
