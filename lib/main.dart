import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Hydrify/screens/registration/station_owner_registration_screen.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart'; 
import 'screens/station/displayingStatus.dart';
import 'screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase FIRST
  await Supabase.initialize(
    url: 'https://ygrdgnohxkwbkuftieil.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlncmRnbm9oeGt3Ymt1ZnRpZWlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE3NTUyOTgsImV4cCI6MjA1NzMzMTI5OH0.j7jVz-Zx4KcEKxBPHbqRNyMxQmwDsQaEq3xiK4afgxc', 
  );

  // Now initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Station App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/stationOwnerRegistration': (context) => const StationOwnerRegistrationScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLoad();
  }

  Future<void> _checkFirstLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool firstLoad = prefs.getBool('firstLoad') ?? true;

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return; // Prevents navigation issues if the widget is disposed

    if (firstLoad) {
      await prefs.setBool('firstLoad', false);
      _navigateTo(const WelcomeScreen());
    } else {
      _checkUserLogin();
    }
  }

  Future<void> _checkUserLogin() async {
    _navigateTo(const LoginScreen()); // Always navigate to LoginScreen
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
