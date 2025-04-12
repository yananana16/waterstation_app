import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Hydrify/screens/registration/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:Hydrify/screens/login_screen.dart';

class StationOwnerRegistrationScreen extends StatefulWidget {
  const StationOwnerRegistrationScreen({super.key});

  @override
  _StationOwnerRegistrationScreenState createState() => _StationOwnerRegistrationScreenState();
}

class _StationOwnerRegistrationScreenState extends State<StationOwnerRegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleIniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  LatLng? _selectedLocation;

  String? _selectedDistrict;

  final List<Map<String, String>> districts = [
    {'id': 'district_001', 'name': 'Arevalo'},
    {'id': 'district_002', 'name': 'City Proper 1'},
    {'id': 'district_003', 'name': 'City Proper 2'},
    {'id': 'district_004', 'name': 'Lapuz'},
    {'id': 'district_005', 'name': 'Molo'},
    {'id': 'district_006', 'name': 'Lapaz'},
    {'id': 'district_007', 'name': 'Jaro 1'},
    {'id': 'district_008', 'name': 'Jaro 2'},
    {'id': 'district_009', 'name': 'Mandurriao'},
  ];

  // Function to register the station owner
  Future<void> _registerStationOwner() async {
    if (_stationNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedDistrict == null ||
        _selectedLocation == null) {
      _showMessage("All fields are required.");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      String customUID = "station_owner_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

      await _firestore.collection('users').doc(uid).set({
        'compliance_approved': false,
        'uid': uid,
        'customUID': customUID,
        'role': 'station_owner',
        'stationName': _stationNameController.text.trim(),
        'district_president': false,
        'federated_president': false,
        'lastName': _lastNameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'middleInitial': _middleIniController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'districtID': _selectedDistrict,
        'status': 'submit_req',
        'createdAt': FieldValue.serverTimestamp(),
        'location': _selectedLocation != null
            ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude)
            : null,
      });

      _showMessage("Registration successful! Waiting for admin approval.");
      Future.microtask(() => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    ));
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Registration failed. Please try again.";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This email is already registered.";
      } else if (e.code == 'weak-password') {
        errorMessage = "Password should be at least 6 characters.";
      }
      _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Station Owner')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Your Account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildTextField(_stationNameController, 'Business Name'),
              _buildTextField(_lastNameController, 'Last Name'),
              _buildTextField(_firstNameController, 'First Name'),
              _buildTextField(_middleIniController, 'Middle Initial (Optional)'),
              _buildTextField(_phoneController, 'Phone Number', keyboardType: TextInputType.phone),
              _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
              _buildTextField(_passwordController, 'Password', obscureText: true),
              _buildTextField(_confirmPasswordController, 'Confirm Password', obscureText: true),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: _inputDecoration('Select District'),
                items: districts.map((district) {
                  return DropdownMenuItem(
                    value: district['id'],
                    child: Text(district['name']!),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDistrict = value),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: Text(_selectedLocation != null
                    ? "Location: (${_selectedLocation!.latitude}, ${_selectedLocation!.longitude})"
                    : "Pick Business Location"),
                onPressed: () async {
                  final LatLng? location = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocationPickerScreen()),
                  );
                  if (location != null) {
                    setState(() => _selectedLocation = location);
                  }
                },
              ),

              const SizedBox(height: 20),

              // Register button without OTP functionality
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _registerStationOwner,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Register', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }
}
