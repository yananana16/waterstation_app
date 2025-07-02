import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Hydrify/screens/registration/station_owner_registration_screen.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart'; 
import 'package:permission_handler/permission_handler.dart';

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

// Example usage in any widget:
// import 'package:supabase_flutter/supabase_flutter.dart';
// final supabase = Supabase.instance.client;
// supabase.from('your_table').select();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: 430, // Typical mobile width (e.g., iPhone 14 Pro Max)
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Water Station App',
              theme: ThemeData(
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Colors.white,
              ),
              initialRoute: '/',
              routes: {
                '/': (context) => const SplashScreen(),
                '/stationOwnerRegistration': (context) => const StationOwnerRegistrationScreen(),
              },
            ),
          ),
        );
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

    if (!mounted) return;

    if (firstLoad) {
      await prefs.setBool('firstLoad', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
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

// --- Onboarding Flow ---
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (_page == 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _page == 0) setState(() => _page = 1);
      });
    }
  }

  void _next() {
    setState(() {
      if (_page < 3) _page++;
    });
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _enableLocation() {
    setState(() => _page = 3);
  }

  void _requestLocation(PermissionStatus status) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bigger logo, closer to text
            Image.asset('assets/logo.png', height: 200),
            const SizedBox(height: 12),
            const Text(
              'H₂OGO',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            const Text(
              'Where safety meets efficiency.',
              style: TextStyle(fontSize: 14, color: Color(0xFF3A7CA5)),
            ),
            const SizedBox(height: 32),
            // Loading indicator below the logo/text
            const CircularProgressIndicator(color: Color(0xFF1565C0)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', height: 180),
                    const SizedBox(height: 40),
                    const Text(
                      'Welcome!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "We're glad you're here. Let's stay hydrated together!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Pure, safe, and refreshing water—just a tap away.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(foregroundColor: Colors.black54),
                          child: const Text("Skip"),
                        ),
                        ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
                          child: const Text("Next", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationIntro() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/undraw_my-current-location_tudq-removebg-preview 1.png', height: 180),
                    const SizedBox(height: 40),
                    const Text(
                      'Find the best water station near you',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Enable location access to discover nearby water stations and ensure smooth deliveries.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(foregroundColor: Colors.black54),
                          child: const Text("Skip"),
                        ),
                        ElevatedButton(
                          onPressed: _enableLocation,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
                          child: const Text("Enable", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPermission() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/undraw_my-current-location_tudq-removebg-preview 1.png', height: 180),
                    const SizedBox(height: 40),
                    const Icon(Icons.location_on, color: Colors.blue, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      "Allow H₂OGO to access this device's location?",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        final status = await Permission.location.request();
                        _requestLocation(status);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('While using the app', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final status = await Permission.location.request();
                        _requestLocation(status);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Only this time', style: TextStyle(color: Colors.blue)),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Deny', style: TextStyle(color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_page) {
      case 0:
        return _buildSplash();
      case 1:
        return _buildWelcome();
      case 2:
        return _buildLocationIntro();
      case 3:
        return _buildLocationPermission();
      default:
        return _buildSplash();
    }
  }
}
