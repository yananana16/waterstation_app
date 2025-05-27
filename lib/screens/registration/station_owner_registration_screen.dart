import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Hydrify/screens/registration/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http; // <-- Add this import
import 'dart:convert'; // <-- Add this import

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

  bool _isPasswordVisible = false; // Added for password visibility toggle
  bool _isConfirmPasswordVisible = false; // Added for confirm password visibility toggle

  // Helper function to perform reverse geocoding using Nominatim
  Future<String?> _getAddressFromLatLng(LatLng location) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${location.latitude}&lon=${location.longitude}';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'HydrifyApp/1.0 (your@email.com)'
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
    } catch (e) {
      // Optionally handle error
    }
    return null;
  }

  // Function to handle registration
  void _registerStationOwner() async {
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
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Generate custom document ID
      String documentId = "station_owner_${DateTime.now().millisecondsSinceEpoch}";

      final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String membershipType = args?['membership'] ?? 'new'; // Default to 'new' if not provided

      // Get address from coordinates using Nominatim
      String? address = await _getAddressFromLatLng(_selectedLocation!);

      // Get district name from selected district ID
      String? districtName = districts.firstWhere(
        (district) => district['id'] == _selectedDistrict,
        orElse: () => {'name': ''}
      )['name'];

      // Save user details in Firestore
      await _firestore.collection('station_owners').doc(documentId).set({
        'stationName': _stationNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'middleInitial': _middleIniController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'districtID': _selectedDistrict,
        'districtName': districtName, // <-- Add districtName here
        'location': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        },
        'address': address ?? '', // <-- Store the address from Nominatim
        'userId': userCredential.user!.uid, // Link to Firebase Authentication user ID
        'createdAt': FieldValue.serverTimestamp(), // Add createdAt field
        'status': 'submitreq', // Add status field
        'membership': membershipType, // Add membership field
      });

      // Add user to 'users' collection with role and president flags
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'role': 'owner',
        'federated_president': false,
        'district_president': false,
        'email': _emailController.text.trim(),
        'stationOwnerDocId': documentId,
        'customUID': documentId, // <-- Add customUID field
        'createdAt': FieldValue.serverTimestamp(),
        'districtName': districtName,
      });

      // Show success dialog with improved UI
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing the dialog
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // Disable back button
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 60), // Success icon
                SizedBox(height: 20),
                Text(
                  "Registration Successful!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Navigate to Login Screen
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showMessage("Registration failed: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String membershipType = args?['membership'] ?? 'new'; // Default to 'new' if not provided

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Your Account',
          style: TextStyle(color: Colors.blue), // Changed app bar title font color to blue
        ),
        iconTheme: const IconThemeData(color: Colors.blue), // Changed app bar icon color to blue
        backgroundColor: Colors.white, // Set app bar background color to white
        elevation: 0, // Removed app bar shadow
      ),
      body: Container(
        color: Colors.white, // Changed background color to white
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                _buildTextField(_stationNameController, 'Business Name'),
                _buildTextField(_lastNameController, 'Last Name'),
                _buildTextField(_firstNameController, 'First Name'),
                _buildTextField(_middleIniController, 'Middle Initial (Optional)'),
                _buildTextField(_phoneController, 'Phone Number', keyboardType: TextInputType.phone),
                _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                _buildTextField(_passwordController, 'Password', obscureText: !_isPasswordVisible, isPassword: true),
                _buildTextField(_confirmPasswordController, 'Confirm Password', obscureText: !_isConfirmPasswordVisible, isPassword: true),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: InputDecoration(
                    labelText: 'Select District',
                    labelStyle: const TextStyle(color: Colors.black, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: districts.map((district) {
                    return DropdownMenuItem(
                      value: district['id'],
                      child: Row(
                        children: [
                          const Icon(Icons.location_city, color: Colors.blue), // Added icon for better UI
                          const SizedBox(width: 10),
                          Text(district['name']!, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDistrict = value),
                  style: const TextStyle(color: Colors.black), // Improved dropdown text style
                  dropdownColor: Colors.white, // Set dropdown background color to white
                  menuMaxHeight: 200.0, // Added max height for dropdown
                ),

                const SizedBox(height: 20),

                _buildLocationButton(),

                const SizedBox(height: 20),

                // Register button without OTP functionality
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildRegisterButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black, fontSize: 14), // Black label with smaller font
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue), // Blue border
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue), // Blue border when enabled
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue, width: 2), // Thicker blue border on focus
          ),
          filled: true,
          fillColor: Colors.white, // White background for input fields
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.blue, // Blue visibility icon
                  ),
                  onPressed: () {
                    setState(() {
                      if (label == 'Password') {
                        _isPasswordVisible = !_isPasswordVisible;
                      } else if (label == 'Confirm Password') {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      }
                    });
                  },
                )
              : null,
        ),
        style: const TextStyle(color: Colors.black), // Black text inside input fields
      ),
    );
  }

  ElevatedButton _buildLocationButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.location_on, color: Colors.blue), // Blue icon
      label: Text(
        _selectedLocation != null
            ? "Location: (${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)})"
            : "Pick Location",
        style: const TextStyle(fontSize: 16, color: Colors.blue), // Blue text
      ),
      onPressed: () async {
        final LatLng? location = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LocationPickerScreen()),
        );
        if (location != null) {
          setState(() => _selectedLocation = location);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // White background
        side: const BorderSide(color: Colors.blue), // Blue border
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  ElevatedButton _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _registerStationOwner,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue, // Blue background
        foregroundColor: Colors.white, // White text
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Register', style: TextStyle(fontSize: 16)), // Button text
    );
  }
}
