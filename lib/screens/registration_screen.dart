import 'package:flutter/material.dart';
import 'customer/customer_registration_screen.dart';
import 'registration/station_owner_registration_screen.dart';
import 'registration/membership_confirmation_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  void _navigateToRegistration(BuildContext context, String userType) {
    if (userType == "Customer") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomerRegistrationScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MembershipConfirmationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF), // light background color
      body: Column(
        children: [
          const SizedBox(height: 60),
          
          // Illustration
          Image.asset(
            'assets/undraw_thought-process_pavs-removebg-preview 1.png', // Replace with your actual image asset
            height: 220,
          ),

          const SizedBox(height: 20),

          // Content container
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please select your role:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Customer Button
                  ElevatedButton(
                    onPressed: () => _navigateToRegistration(context, "Customer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6CA7FF),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Customer',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Station Button
                  ElevatedButton(
                    onPressed: () => _navigateToRegistration(context, "Station Owner"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6CA7FF),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Water Refilling Station',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Login Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
