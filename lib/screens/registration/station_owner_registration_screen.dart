import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Hydrify/screens/registration/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http; // <-- Add this import
import 'dart:convert'; // <-- Add this import
import 'package:Hydrify/screens/login_screen.dart'; // <-- Import LoginScreen

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
  String _membershipType = 'new'; // Default to 'new'

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
    // Ensure phone number starts with +63
    String phone = _phoneController.text.trim();
    if (!phone.startsWith('+63')) {
      if (phone.startsWith('0')) {
        phone = '+63' + phone.substring(1);
      } else if (phone.startsWith('63')) {
        phone = '+$phone';
      } else {
        phone = '+63$phone';
      }
    }
    _phoneController.text = phone;

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
      // Check if email is already registered
      final List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(_emailController.text.trim());
      if (signInMethods.isNotEmpty) {
        setState(() => _isLoading = false);
        _showMessage("This email is already registered. Please use another email or login.");
        return;
      }

      // Show email verification dialog before registration
      bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Icon(Icons.email_outlined, color: Colors.blue, size: 70),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Verify Your Email",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  "We will send a verification link to:\n${_emailController.text.trim()}",
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please make sure your email is correct.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: const Text("Send Verification"),
              ),
            ],
          ),
        ),
      );

      if (proceed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Generate custom document ID
      String documentId = "station_owner_${DateTime.now().millisecondsSinceEpoch}";

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
        'phone': phone, // <-- Use formatted phone number
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
        'membership': _membershipType, // Use local state
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

      // Show email verification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: const Icon(Icons.email_outlined, color: Colors.blue, size: 70),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Verify Your Email",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "A verification link has been sent to your email address. Please check your inbox and verify your email before logging in.",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Didn't receive the email? Check your spam folder.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _auth.currentUser?.reload();
                      final isVerified = _auth.currentUser?.emailVerified ?? false;
                      if (isVerified) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => LoginScreen()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please verify your email before proceeding to login."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Go to Login",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // Do not navigate to login automatically; wait for user to verify email and press OK

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
        color: Colors.white,
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

                // --- Membership Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _membershipType = 'new';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _membershipType == 'new' ? Colors.blue : Colors.white,
                          foregroundColor: _membershipType == 'new' ? Colors.white : Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('New Member', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _membershipType = 'existing';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _membershipType == 'existing' ? Colors.blue : Colors.white,
                          foregroundColor: _membershipType == 'existing' ? Colors.white : Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Existing Member', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),

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
          prefixText: label == 'Phone Number' ? '+63 ' : null, // Show +63 as prefix in UI
        ),
        style: const TextStyle(color: Colors.black), // Black text inside input fields
        onChanged: (value) {
          if (label == 'Phone Number') {
            // Remove any leading zero if user types it after +63
            if (value.startsWith('0')) {
              controller.text = value.replaceFirst('0', '');
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          }
        },
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
