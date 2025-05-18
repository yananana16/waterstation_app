import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Hydrify/screens/login_screen.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  _CustomerRegistrationScreenState createState() => _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleIniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _registerCustomer() async {
    String lastName = _lastNameController.text.trim();
    String firstName = _firstNameController.text.trim();
    String middleIni = _middleIniController.text.trim();
    String phone = _phoneController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (lastName.isEmpty || firstName.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage("Please fill all required fields.");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Register user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;

        // Store user data in Firestore
        await _firestore.collection('customers').doc(uid).set({
          'uid': uid,
          'lastName': lastName,
          'firstName': firstName,
          'middleInitial': middleIni,
          'phone': phone,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add to users collection with role: "customers"
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'role': 'customer',
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showMessage("Registration successful! Waiting for admin approval.");
      Future.microtask(() => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    ));
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Registration failed.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFE3F2FD), // Light blue background
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Image.asset('assets/logo.png', height: 80), // Replace with your logo asset
                  const SizedBox(height: 10),
                  const Text('Sign up', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white, // White background for the form
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(_firstNameController, 'Enter your First Name', Icons.person, iconColor: Colors.blue),
                        const SizedBox(height: 10),
                        _buildTextField(_lastNameController, 'Enter your Last Name', Icons.person, iconColor: Colors.blue),
                        const SizedBox(height: 10),
                        _buildTextField(_phoneController, 'Contact Number', Icons.phone, keyboardType: TextInputType.phone, iconColor: Colors.blue),
                        const SizedBox(height: 10),
                        _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress, iconColor: Colors.blue),
                        const SizedBox(height: 10),
                        _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true, iconColor: Colors.blue),
                        const SizedBox(height: 10),
                        _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock, obscureText: true, iconColor: Colors.blue),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _registerCustomer,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                  backgroundColor: Colors.blue, // Blue background
                                ),
                                child: const Text('Sign Up', style: TextStyle(fontSize: 16, color: Colors.white)), // White text
                              ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            ),
                            child: const Text(
                              'Already have an account? Login',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText, IconData icon,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text, Color iconColor = Colors.grey}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        filled: true,
        fillColor: Colors.white, // White background for text fields
      ),
    );
  }
}
