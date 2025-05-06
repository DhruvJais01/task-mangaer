import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/node.dart';
import 'providers/node_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/sign_in_screen.dart';
import 'screens/dash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyB3GovVeCVooPJdv9ify6CSieKec0dguzc",
            authDomain: "task-manager-35eb3.firebaseapp.com",
            projectId: "task-manager-35eb3",
            storageBucket: "task-manager-35eb3.firebasestorage.app",
            messagingSenderId: "643455994819",
            appId: "1:643455994819:web:7abe922fc839ec32b88b76"));
  } else {
    await Firebase.initializeApp();
  }

  try {
    // Initialize Hive
    await Hive.initFlutter();
    Hive.registerAdapter(NodeAdapter());
    await Hive.openBox<Node>('nodes');
  } catch (e) {
    // If Hive fails, we'll still run the app with in-memory data
    debugPrint('Error initializing Hive: $e');
  }

  runApp(const HierarchicalListApp());
}

class HierarchicalListApp extends StatelessWidget {
  const HierarchicalListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NodeProvider(),
      child: MaterialApp(
        title: 'Inovizia Task Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: kDebugMode
            ? const DashScreen()
            : StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData) {
                    return const DashScreen();
                  }
                  return const SignInScreen();
                },
              ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
