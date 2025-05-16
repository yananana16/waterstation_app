import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';
import 'submit_compliance_screen.dart';

class DisplayStatusScreen extends StatefulWidget {
  const DisplayStatusScreen({super.key});

  @override
  _DisplayStatusScreenState createState() => _DisplayStatusScreenState();
}

class _DisplayStatusScreenState extends State<DisplayStatusScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot? userDoc;

    // Try station_owners first
    userDoc = await _firestore.collection('station_owners').doc(user.uid).get();
    if (!userDoc.exists) {
      // Try customers if not found in station_owners
      userDoc = await _firestore.collection('customers').doc(user.uid).get();
    }

    if (userDoc.exists) {
      setState(() {
        _status = userDoc!['status'];
      });
    } else {
      // Not found in either collection, treat as blocked
      setState(() {
        _status = '';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _status == 'pending_approval' ? null : AppBar(
        title: const Text('Display Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _status == 'submit_req'
              ? _buildSubmitRequirementScreen()
              : _status == 'pending_approval'
                  ? _buildPendingApprovalScreen()
                  : _redirectToLoginScreen(), // Redirect to login if blocked access
    );
  }

  /// Redirect to Login Screen for Blocked Access
  Widget _redirectToLoginScreen() {
    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    });
    return const Center(child: CircularProgressIndicator());
  }

  /// 📌 **Submit Requirement Screen**
  Widget _buildSubmitRequirementScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Submit Requirements',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubmitCompliancePage()),
              );
            },
            child: const Text('Go to Compliance Page'),
          ),
        ],
      ),
    );
  }

  /// 🟠 **Pending Approval UI**
  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_late_rounded, size: 80, color: Color(0xFF609EF4)),
                const SizedBox(height: 24),
                const Text(
                  'Pending Verification',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please check your email regularly for updates. We will send a confirmation to your email once your account has been verified.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF609EF4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Log out',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
