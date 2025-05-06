import 'package:flutter/material.dart';
import 'home_screen.dart'; // Your main dashboard

class DashScreen extends StatelessWidget {
  const DashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HomeScreen(); // Or wrap with Scaffold if needed
  }
}
