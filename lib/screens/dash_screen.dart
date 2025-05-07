import 'package:flutter/material.dart';
import 'home_screen.dart'; // Your main dashboard

class DashScreen extends StatelessWidget {
  const DashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen(); // Or wrap with Scaffold if needed
  }
}
