import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = false; // Add loading state
  final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
  firebase_auth.User? user;

  final List<Widget> _screens = [
    const HomeScreen(), // Changed from DeliveryScreen to NotificationsScreen
    StationsScreen(),
    OrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    user = auth.currentUser;
  }

  void _onTabTapped(int index) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading delay

    setState(() {
      _currentIndex = index;
      _isLoading = false; // Hide loading indicator
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (_isLoading) // Show loading indicator
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          // Removed Notifications tab here
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Stations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Add a static variable to track if the dialog has been shown in this session
  static bool _noAddressDialogShown = false;

  Future<String> _getCustomerName() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user != null) {
      final DocumentSnapshot customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (customerDoc.exists) {
        return customerDoc['firstName'] ?? 'Customer';
      }
    }
    return 'Customer';
  }

  Future<List<Map<String, dynamic>>> _getNearestStations() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user == null) throw Exception('User not logged in.');

    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();

    var defaultAddressId = customerDoc.data()?['defaultAddressId'];
    if (defaultAddressId == "" || defaultAddressId == null) {
      defaultAddressId = null;
    }
    if (defaultAddressId == null) {
      // No address set
      return [];
    }

    final defaultAddressDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .collection('address')
        .doc(defaultAddressId)
        .get();

    if (!defaultAddressDoc.exists) {
      // No address found
      return [];
    }

    final double customerLat = defaultAddressDoc['latitude'];
    final double customerLon = defaultAddressDoc['longitude'];

    final QuerySnapshot stationsSnapshot = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('status', isEqualTo: 'approved')
        .get();

    if (stationsSnapshot.docs.isEmpty) {
      throw Exception('No stations found.');
    }

    final List<Map<String, dynamic>> stations = stationsSnapshot.docs.map((station) {
      final double stationLat = station['location']['latitude'];
      final double stationLon = station['location']['longitude'];
      final double distance = _calculateDistance(
        customerLat,
        customerLon,
        stationLat,
        stationLon,
      );

      return {
        'name': station['stationName'],
        'distance': distance,
        'address': station['address'],
        'stationOwnerId': station.id,
        'latitude': stationLat,
        'longitude': stationLon,
      };
    }).toList();

    stations.sort((a, b) => a['distance'].compareTo(b['distance']));
    return stations.take(3).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getCustomerName(),
      builder: (context, nameSnapshot) {
        String displayName = 'User';
        if (nameSnapshot.connectionState == ConnectionState.done && nameSnapshot.hasData) {
          displayName = nameSnapshot.data!;
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getNearestStations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If no address is detected, show dialog and empty recommendations
            if (snapshot.hasData && snapshot.data != null && snapshot.data!.isEmpty) {
              // Show dialog only once per session after login
              if (!_noAddressDialogShown) {
                _noAddressDialogShown = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                      title: Column(
                        children: const [
                          Icon(Icons.location_off, color: Color(0xFF1565C0), size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No Address Detected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF1565C0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      content: const Text(
                        'Please add your address to get personalized station recommendations and enjoy a better experience.',
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const MyAddressesScreen()),
                            );
                          },
                          child: const Text('Add Address'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Later'),
                        ),
                      ],
                    ),
                  );
                });
              }

              return Scaffold(
                backgroundColor: Colors.white,
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with logo, cart, and profile
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                            child: Row(
                              children: [
                                const SizedBox(width: 120, height: 36),
                                // Add the text beside the logo (fixed position, so also add in the Stack below)
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.shopping_cart, color: Colors.black),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const MyCartScreen()),
                                    );
                                  },
                                ),
                                // Add notifications icon beside cart
                                IconButton(
                                  icon: const Icon(Icons.notifications, color: Colors.black),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => NotificationsScreen()),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Icon(Icons.person, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          // Illustration and greeting
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    'assets/assets_illustraion.png', // Place your illustration here
                                    height: 150,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      "Welcome!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // My Orders section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "My Orders",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _OrderStatusIcon(
                                      icon: Icons.shopping_bag,
                                      label: "Order Received",
                                    ),
                                    _OrderStatusIcon(
                                      icon: Icons.timelapse,
                                      label: "In Progress",
                                    ),
                                    _OrderStatusIcon(
                                      icon: Icons.local_shipping,
                                      label: "Out for Delivery",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Promo card
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        "Get 10% off on your first order!",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1565C0),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      ),
                                      child: const Text("Buy Now"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Recommendations section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                            child: const Text(
                              "Recommendations",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // No recommendations if address is null
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    // Big fixed-position logo (overlapping, not moving other widgets)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IgnorePointer(
                            child: Image.asset(
                              'assets/logo.png', // Place your logo at this path
                              height: 100,
                              width: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add the text beside the logo
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SizedBox(height: 18),
                              Text(
                                "H₂OGO",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Color(0xFF1565C0),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Where safety meets efficiency.",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF3A7CA5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // ...existing code for bottomNavigationBar...
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                ),
              );
            }

            final stations = snapshot.data ?? [];

            return Scaffold(
              backgroundColor: Colors.white,
              body: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with logo, cart, and profile
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                          child: Row(
                            children: [
                              const SizedBox(width: 120, height: 36),
                              // Add the text beside the logo (fixed position, so also add in the Stack below)
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.shopping_cart, color: Colors.black),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const MyCartScreen()),
                                  );
                                },
                              ),
                              // Add notifications icon beside cart
                              IconButton(
                                icon: const Icon(Icons.notifications, color: Colors.black),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => NotificationsScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: Icon(Icons.person, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        // Illustration and greeting
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Image.asset(
                                  'assets/assets_illustraion.png', // Place your illustration here
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "Welcome!",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // My Orders section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "My Orders",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _OrderStatusIcon(
                                    icon: Icons.shopping_bag,
                                    label: "Order Received",
                                  ),
                                  _OrderStatusIcon(
                                    icon: Icons.timelapse,
                                    label: "In Progress",
                                  ),
                                  _OrderStatusIcon(
                                    icon: Icons.local_shipping,
                                    label: "Out for Delivery",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Promo card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Get 10% off on your first order!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    ),
                                    child: const Text("Buy Now"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Recommendations section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: const Text(
                            "Recommendations",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        // Only show recommendations if stations is not empty
                        if (stations.isNotEmpty)
                          ...stations.take(1).map((station) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      station['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      station['address'],
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: const [
                                        Icon(Icons.access_time, size: 16, color: Colors.black54),
                                        SizedBox(width: 4),
                                        Text(
                                          "Operating Hours 8:00 AM - 7:00 PM",
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(5, (i) => const Icon(Icons.star, size: 16, color: Colors.amber)),
                                        ),
                                        const Spacer(),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => StationDetailsScreen(
                                                  stationName: station['name'],
                                                  ownerName: 'Owner Name',
                                                  address: station['address'],
                                                  stationOwnerId: station['stationOwnerId'],
                                                  latitude: station['latitude'],
                                                  longitude: station['longitude'],
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.shopping_cart, size: 16, color: Colors.white),
                                          label: const Text("Order"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1565C0),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // Big fixed-position logo (overlapping, not moving other widgets)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IgnorePointer(
                          child: Image.asset(
                            'assets/logo.png', // Place your logo at this path
                            height: 100,
                            width: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Add the text beside the logo
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SizedBox(height: 18),
                            Text(
                              "H₂OGO",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Color(0xFF1565C0),
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Where safety meets efficiency.",
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF3A7CA5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ...existing code for bottomNavigationBar...
            );
          },
        );
      },
    );
  }
}

class _OrderStatusIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _OrderStatusIcon({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          radius: 28,
          child: Icon(icon, color: const Color(0xFF1565C0), size: 28),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class MyCartScreen extends StatefulWidget {
  const MyCartScreen({super.key});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  bool _editMode = false;
  // Use ValueNotifier for selection so UI can auto-refresh
  final ValueNotifier<Set<String>> _selectedCartDocIds = ValueNotifier<Set<String>>({});

  // Helper to group cart items by stationOwnerId
  Map<String, List<Map<String, dynamic>>> _groupByStation(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final stationId = data['stationOwnerId'] ?? 'Unknown Station';
      if (!grouped.containsKey(stationId)) {
        grouped[stationId] = [];
      }
      grouped[stationId]!.add({...data, 'cartDocId': doc.id});
    }
    return grouped;
  }


  double _calculateSelectedTotal(List<QueryDocumentSnapshot> docs, Set<String> selectedIds) {
    double sum = 0;
    for (var doc in docs) {
      if (selectedIds.contains(doc.id)) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['price'] ?? 0) as num;
        final quantity = (data['quantity'] ?? 1) as num;
        sum += price * quantity;
      }
    }
    return sum;
  }

  // Helper to determine selection state for a station group
  CheckboxState _getStationCheckboxState(List<Map<String, dynamic>> items, Set<String> selectedIds) {
    final ids = items.map((item) => item['cartDocId'] as String).toList();
    final selectedCount = ids.where((id) => selectedIds.contains(id)).length;
    if (selectedCount == 0) return CheckboxState.none;
    if (selectedCount == ids.length) return CheckboxState.all;
    return CheckboxState.partial;
  }

  Future<void> _payWithPayMongoCart({
    required List<Map<String, dynamic>> lineItems,
    required BuildContext context,
  }) async {
    const secretKey = 'sk_test_tqWtvE1KNtAwrEYejUhbkUdy'; // Replace with your live key for production
    final url = Uri.parse('https://api.paymongo.com/v1/checkout_sessions');

    final body = jsonEncode({
      "data": {
        "attributes": {
          "billing": {
            "name": "Customer",
          },
          "send_email_receipt": false,
          "show_description": false,
          "show_line_items": true,
          "line_items": lineItems,
          "payment_method_types": ["gcash", "card"],
          "success_url": "https://example.com/success",
          "cancel_url": "https://example.com/cancel"
        }
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$secretKey:'))}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data['data']['attributes']?['checkout_url'];

        if (checkoutUrl != null && checkoutUrl is String) {
          final uri = Uri.parse(checkoutUrl);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              // ignore: deprecated_member_use
              if (await canLaunch(checkoutUrl)) {
                // ignore: deprecated_member_use
                await launch(checkoutUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch the payment URL.')),
                );
              }
            }
          } catch (e) {
            // ignore: deprecated_member_use
            if (await canLaunch(checkoutUrl)) {
              // ignore: deprecated_member_use
              await launch(checkoutUrl);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch the payment URL: $e')),
              );
            }
          }

          // --- Add order to Firestore after successful payment ---
          final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
          final firebase_auth.User? user = auth.currentUser;
          if (user != null) {
            // Calculate total price from lineItems
            double totalPrice = 0;
            for (var item in lineItems) {
              final amount = (item['amount'] ?? 0) as int;
              final quantity = (item['quantity'] ?? 1) as int;
              totalPrice += (amount / 100.0) * quantity;
            }

            // Generate a custom OrderID
            final String orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 5)}';

            // Get stationOwnerId from lineItems if available
            String? stationOwnerId;
            if (lineItems.isNotEmpty && lineItems.first.containsKey('stationOwnerId')) {
              stationOwnerId = lineItems.first['stationOwnerId'];
            }

            final orderData = {
              'orderId': orderId,
              'customerId': user.uid,
              'products': lineItems,
              'stationOwnerId': stationOwnerId,
              'status': 'Pending',
              'timestamp': FieldValue.serverTimestamp(),
              'totalPrice': totalPrice,
            };

            // Add order to the global orders collection
            await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderData);

            // Add order to each station owner's orders subcollection (group by stationOwnerId)
            if (stationOwnerId != null) {
              await FirebaseFirestore.instance
                  .collection('station_owners')
                  .doc(stationOwnerId)
                  .collection('orders')
                  .doc(orderId)
                  .set(orderData);
            }

            // --- Remove paid selected cart items from customer's cart ---
            // Find all selected cart doc IDs from the current ValueNotifier
            final selectedCartDocIds = _selectedCartDocIds.value;
            final batch = FirebaseFirestore.instance.batch();
            for (final cartDocId in selectedCartDocIds) {
              final docRef = FirebaseFirestore.instance
                  .collection('customers')
                  .doc(user.uid)
                  .collection('cart')
                  .doc(cartDocId);
              batch.delete(docRef);
            }
            await batch.commit();
            _selectedCartDocIds.value = {};
            // ------------------------------------------------------------
          }
          // ------------------------------------------------------
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checkout URL missing in response.')),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        String errorMsg = 'Failed to create checkout session';
        if (errorData is Map &&
            errorData.containsKey('errors') &&
            errorData['errors'] is List &&
            errorData['errors'].isNotEmpty) {
          errorMsg = errorData['errors'][0]['detail'] ?? errorMsg;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
              });
            },
            child: Text(
              _editMode ? 'Done' : 'Edit',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFFF5F8FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('cart')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty.',
                    style: TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }
          final docs = snapshot.data!.docs;
          final grouped = _groupByStation(docs);

          return ValueListenableBuilder<Set<String>>(
            valueListenable: _selectedCartDocIds,
            builder: (context, selectedIds, _) {
              final selectedTotal = _calculateSelectedTotal(docs, selectedIds);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          '(${docs.length}) Items',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1565C0)),
                        ),
                        const Spacer(),
                        Checkbox(
                          value: selectedIds.length == docs.length && docs.isNotEmpty
                              ? true
                              : selectedIds.isEmpty
                                  ? false
                                  : null,
                          tristate: true,
                          onChanged: (checked) {
                            if (checked == true) {
                              _selectedCartDocIds.value = docs.map((d) => d.id).toSet();
                            } else {
                              _selectedCartDocIds.value = {};
                            }
                          },
                          activeColor: const Color(0xFF1565C0),
                        ),
                        const Text('Select All', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setInnerState) {
                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          children: grouped.entries.map((entry) {
                            final stationId = entry.key;
                            final items = entry.value;
                            final ids = items.map((item) => item['cartDocId'] as String).toList();
                            final stationCheckboxState = _getStationCheckboxState(items, selectedIds);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.store, color: Color(0xFF1565C0)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          stationId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                      ),
                                      Checkbox(
                                        value: stationCheckboxState == CheckboxState.all
                                            ? true
                                            : stationCheckboxState == CheckboxState.none
                                                ? false
                                                : null,
                                        tristate: true,
                                        onChanged: (checked) {
                                          if (checked == true) {
                                            _selectedCartDocIds.value = {
                                              ...selectedIds,
                                              ...ids,
                                            };
                                          } else {
                                            _selectedCartDocIds.value = {
                                              ...selectedIds.where((id) => !ids.contains(id)),
                                            };
                                          }
                                        },
                                        activeColor: const Color(0xFF1565C0),
                                      ),
                                      const Text('Select Station', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                ...items.map((item) {
                                  final cartDocId = item['cartDocId'] as String;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: selectedIds.contains(cartDocId),
                                            onChanged: (checked) {
                                              if (checked == true) {
                                                _selectedCartDocIds.value = {...selectedIds, cartDocId};
                                              } else {
                                                _selectedCartDocIds.value = {...selectedIds}..remove(cartDocId);
                                              }
                                            },
                                            activeColor: const Color(0xFF1565C0),
                                          ),
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.local_drink, color: Colors.blue.shade300, size: 36),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF1565C0),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item['type'] ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₱ ${(item['price'] ?? 0).toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: Color(0xFF1565C0),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Subtotal: ₱ ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.remove, size: 18),
                                                            onPressed: (item['quantity'] ?? 1) > 1
                                                                ? () async {
                                                                    await FirebaseFirestore.instance
                                                                        .collection('customers')
                                                                        .doc(user.uid)
                                                                        .collection('cart')
                                                                        .doc(item['cartDocId'])
                                                                        .update({'quantity': (item['quantity'] ?? 1) - 1});
                                                                  }
                                                                : null,
                                                          ),
                                                          Text(
                                                            (item['quantity'] ?? 1).toString(),
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.add, size: 18),
                                                            onPressed: () async {
                                                              await FirebaseFirestore.instance
                                                                  .collection('customers')
                                                                  .doc(user.uid)
                                                                  .collection('cart')
                                                                  .doc(item['cartDocId'])
                                                                  .update({'quantity': (item['quantity'] ?? 1) + 1});
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Add Remove button (always visible)
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red),
                                                      tooltip: 'Remove',
                                                      onPressed: () async {
                                                        await FirebaseFirestore.instance
                                                            .collection('customers')
                                                            .doc(user.uid)
                                                            .collection('cart')
                                                            .doc(item['cartDocId'])
                                                            .delete();
                                                        _selectedCartDocIds.value = {...selectedIds}..remove(item['cartDocId']);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                '₱ ${selectedTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: selectedIds.isNotEmpty
                              ? () async {
                                  final selectedDocs = docs.where((doc) => selectedIds.contains(doc.id)).toList();
                                  final lineItems = selectedDocs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return {
                                      "currency": "PHP",
                                      "amount": ((data['price'] ?? 0) * 100).toInt(),
                                      "name": data['name'] ?? 'Product',
                                      "quantity": data['quantity'] ?? 1,
                                    };
                                  }).toList();
                                  if (lineItems.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No items selected for checkout.')),
                                    );
                                    return;
                                  }
                                  await _payWithPayMongoCart(
                                    lineItems: lineItems,
                                    context: context,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.payment, size: 18, color: Colors.white),
                          label: Text(
                            'Check Out (${selectedIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Helper enum for checkbox state
enum CheckboxState { none, partial, all }

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  Future<String> _getCustomerName() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user != null) {
      final DocumentSnapshot customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (customerDoc.exists) {
        return customerDoc['firstName'] ?? 'Customer';
      }
    }
    return 'Customer';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getCustomerName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
        }

        return Scaffold(
          appBar: AppBar(
            // Add back button
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            automaticallyImplyLeading: false, // Remove default back button
            backgroundColor: const Color(0xFF1565C0), // Dark blue header
            title: Row(
              children: const [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF1565C0)),
                ),
                SizedBox(width: 10),
                Text(
                  'Profile',
                  style: TextStyle(color: Colors.white), // Set text color to white
                ),
              ],
            ),
          ),
          body: ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.blue, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notification Title',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '2 hours ago',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Notification description goes here.',
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class StationDetailsScreen extends StatefulWidget {
  final String stationName;
  final String ownerName;
  final String address;
  final String stationOwnerId;
  final double latitude;
  final double longitude;

  const StationDetailsScreen({
    super.key,
    required this.stationName,
    required this.ownerName,
    required this.address,
    required this.stationOwnerId,
    required this.latitude,
    required this.longitude,
  });

  @override
  _StationDetailsScreenState createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  String? _dynamicAddress;
  final Map<String, int> _offerQuantities = {};

  // (Removed unused _fetchComplianceStatuses method)

  Future<void> _payWithPayMongo({
    required String name,
    required double price,
    required int quantity,
    required BuildContext context,
  }) async {
    const secretKey = 'sk_test_tqWtvE1KNtAwrEYejUhbkUdy'; // Replace with your live key for production
    final url = Uri.parse('https://api.paymongo.com/v1/checkout_sessions');
    final amount = (price * 100).toInt(); // Convert PHP to centavos

    final body = jsonEncode({
      "data": {
        "attributes": {
          "billing": {
            "name": name,
          },
          "send_email_receipt": false,
          "show_description": false,
          "show_line_items": true,
          "line_items": [
            {
              "currency": "PHP",
              "amount": amount,
              "name": name,
              "quantity": quantity,
            }
          ],
          "payment_method_types": ["gcash", "card"],
          "success_url": "https://example.com/success",
          "cancel_url": "https://example.com/cancel"
        }
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$secretKey:'))}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data['data']['attributes']?['checkout_url'];

        if (checkoutUrl != null && checkoutUrl is String) {
          final uri = Uri.parse(checkoutUrl);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              // ignore: deprecated_member_use
              if (await canLaunch(checkoutUrl)) {
                // ignore: deprecated_member_use
                await launch(checkoutUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch the payment URL.')),
                );
              }
            }
          } catch (e) {
            // ignore: deprecated_member_use
            if (await canLaunch(checkoutUrl)) {
              // ignore: deprecated_member_use
              await launch(checkoutUrl);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch the payment URL: $e')),
              );
            }
          }

          // --- Add order to Firestore after successful payment ---
          final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
          final firebase_auth.User? user = auth.currentUser;
          if (user != null) {
            // Generate a custom OrderID
            final String orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 5)}';

            final orderData = {
              'orderId': orderId, // Use the custom OrderID
              'customerId': user.uid,
              'productOffer': name,
              'status': 'Pending',
              'timestamp': FieldValue.serverTimestamp(),
              'stationOwnerId': widget.stationOwnerId,
              'quantity': quantity,
              'price': price,
              'totalPrice': price * quantity, // Add this line
            };

            // Add order to the global orders collection
            await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderData);

            // Add order to the station owner's orders subcollection
            await FirebaseFirestore.instance
                .collection('station_owners')
                .doc(widget.stationOwnerId)
                .collection('orders')
                .doc(orderId)
                .set(orderData);
          }
          // ------------------------------------------------------
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checkout URL missing in response.')),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        String errorMsg = 'Failed to create checkout session';
        if (errorData is Map &&
            errorData.containsKey('errors') &&
            errorData['errors'] is List &&
            errorData['errors'].isNotEmpty) {
          errorMsg = errorData['errors'][0]['detail'] ?? errorMsg;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAddressFromCoordinates();
  }

  Future<void> _fetchAddressFromCoordinates() async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${widget.latitude}&lon=${widget.longitude}&addressdetails=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _dynamicAddress = data['display_name'] ?? 'Address not found';
        });
      } else {
        setState(() {
          _dynamicAddress = 'Failed to fetch address';
        });
      }
    } catch (e) {
      setState(() {
        _dynamicAddress = 'Error fetching address';
      });
    }
  }
  // Add for compliance files dialog
  void _showComplianceFilesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 400,
          height: 500,
          child: ComplianceFilesDialog(stationOwnerDocId: widget.stationOwnerId),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main scrollable content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Back Button and Header ---
              Padding(
                padding: const EdgeInsets.only(top: 40, left: 8, right: 8, bottom: 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 60), // Adjusted to account for the back button
              // --- Start: Station Name Header ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.stationName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Map Section
              Container(
                margin: const EdgeInsets.all(16),
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(widget.latitude, widget.longitude),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.latitude, widget.longitude),
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Info & Products
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListView(
                    children: [
                      Text('Address: ${_dynamicAddress ?? "Loading..."}',
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),

                      // --- Compliance Status Card ---
                      
                      // --- End Compliance Status Card ---

                      const Text(
                        'Products Available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('station_owners')
                            .doc(widget.stationOwnerId)
                            .collection('products')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('No products available.'),
                              ),
                            );
                          }
                          final products = snapshot.data!.docs;
                          return Column(
                            children: products.map((product) {
                              final data = product.data() as Map<String, dynamic>;
                              final productId = product.id;
                              final waterType = data['waterType'] ?? 'N/A';
                              final offers = data['offers'] ?? {};
                              final delivery = data['delivery'] ?? {};
                              final offerWidgets = <Widget>[];

                              // Helper to get quantity for a specific offer
                              int getQty(String offerKey) => _offerQuantities['$productId|$offerKey'] ?? 1;

                              // Helper to set quantity for a specific offer
                              void setQty(String offerKey, int qty) {
                                setState(() {
                                  _offerQuantities['$productId|$offerKey'] = qty;
                                });
                              }

                              // Add Round offer
                              if (offers['round'] != null) {
                                final price = offers['round'] is num ? offers['round'].toDouble() : double.tryParse(offers['round'].toString()) ?? 0;
                                final offerKey = 'round';
                                offerWidgets.add(
                                  _buildOfferRow(
                                    label: 'Round',
                                    price: price,
                                    qty: getQty(offerKey),
                                    onQtyChanged: (q) => setQty(offerKey, q),
                                    onAddToCart: () async {
                                      await _addToCart(
                                        context: context,
                                        productId: productId,
                                        offerLabel: 'Round',
                                        price: price,
                                        qty: getQty(offerKey),
                                        type: waterType,
                                      );
                                    },
                                    onOrderNow: () async {
                                      await _payWithPayMongo(
                                        name: '$waterType - Round',
                                        price: price,
                                        quantity: getQty(offerKey),
                                        context: context,
                                      );
                                    },
                                  ),
                                );
                              }
                              // Add Slim offer
                              if (offers['slim'] != null) {
                                final price = offers['slim'] is num ? offers['slim'].toDouble() : double.tryParse(offers['slim'].toString()) ?? 0;
                                final offerKey = 'slim';
                                offerWidgets.add(
                                  _buildOfferRow(
                                    label: 'Slim',
                                    price: price,
                                    qty: getQty(offerKey),
                                    onQtyChanged: (q) => setQty(offerKey, q),
                                    onAddToCart: () async {
                                      await _addToCart(
                                        context: context,
                                        productId: productId,
                                        offerLabel: 'Slim',
                                        price: price,
                                        qty: getQty(offerKey),
                                        type: waterType,
                                      );
                                    },
                                    onOrderNow: () async {
                                      await _payWithPayMongo(
                                        name: '$waterType - Slim',
                                        price: price,
                                        quantity: getQty(offerKey),
                                        context: context,
                                      );
                                    },
                                  ),
                                );
                              }
                              // Add Other1 offer
                              if (offers['other1'] != null && offers['other1']['label'] != null) {
                                final label = offers['other1']['label'] ?? 'Other';
                                final price = offers['other1']['price'] is num
                                    ? offers['other1']['price'].toDouble()
                                    : double.tryParse(offers['other1']['price'].toString()) ?? 0;
                                final offerKey = 'other1';
                                offerWidgets.add(
                                  _buildOfferRow(
                                    label: label,
                                    price: price,
                                    qty: getQty(offerKey),
                                    onQtyChanged: (q) => setQty(offerKey, q),
                                    onAddToCart: () async {
                                      await _addToCart(
                                        context: context,
                                        productId: productId,
                                        offerLabel: label,
                                        price: price,
                                        qty: getQty(offerKey),
                                        type: waterType,
                                      );
                                    },
                                    onOrderNow: () async {
                                      await _payWithPayMongo(
                                        name: '$waterType - $label',
                                        price: price,
                                        quantity: getQty(offerKey),
                                        context: context,
                                      );
                                    },
                                  ),
                                );
                              }
                              // Add Other2 offer
                              if (offers['other2'] != null && offers['other2']['label'] != null) {
                                final label = offers['other2']['label'] ?? 'Other';
                                final price = offers['other2']['price'] is num
                                    ? offers['other2']['price'].toDouble()
                                    : double.tryParse(offers['other2']['price'].toString()) ?? 0;
                                final offerKey = 'other2';
                                offerWidgets.add(
                                  _buildOfferRow(
                                    label: label,
                                    price: price,
                                    qty: getQty(offerKey),
                                    onQtyChanged: (q) => setQty(offerKey, q),
                                    onAddToCart: () async {
                                      await _addToCart(
                                        context: context,
                                        productId: productId,
                                        offerLabel: label,
                                        price: price,
                                        qty: getQty(offerKey),
                                        type: waterType,
                                      );
                                    },
                                    onOrderNow: () async {
                                      await _payWithPayMongo(
                                        name: '$waterType - $label',
                                        price: price,
                                        quantity: getQty(offerKey),
                                        context: context,
                                      );
                                    },
                                  ),
                                );
                              }

                              // Delivery info
                              String deliveryText = '';
                              if (delivery.isNotEmpty) {
                                final available = delivery['available'] ?? '';
                                final price = delivery['price'];
                                deliveryText = 'Delivery: $available'
                                    '${price != null ? ' (₱${price.toString()})' : ''}';
                              }

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        waterType,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (deliveryText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                                          child: Text(deliveryText, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                        ),
                                      ...offerWidgets,
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // --- Start: Fixed-position logo and header (copied from StationsScreen) ---
          Positioned(
            top: 20,
            left: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  child: Image.asset(
                    'assets/logo.png', // Place your logo at this path
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                // Add the text beside the logo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 18),
                    Text(
                      "H₂OGO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF1565C0),
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Where safety meets efficiency.",
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF3A7CA5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyCartScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.black),
                  onPressed: () {
                    // Navigate to settings screen
                  },
                ),
                // Add View Files button
                IconButton(
                  icon: const Icon(Icons.folder, color: Colors.blue),
                  tooltip: "View Files",
                  onPressed: _showComplianceFilesDialog,
                ),
              ],
            ),
          ),
          // --- End: Fixed-position logo and header ---
        ],
      ),
    );
  }

  // Helper widget for each offer row
  Widget _buildOfferRow({
    required String label,
    required double price,
    required int qty,
    required ValueChanged<int> onQtyChanged,
    required VoidCallback onAddToCart,
    required VoidCallback onOrderNow,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: ₱${price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: qty > 1 ? () => onQtyChanged(qty - 1) : null,
              ),
              Text(qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onQtyChanged(qty + 1),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: onAddToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.blue.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Add to Cart"),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onOrderNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Order Now"),
          ),
        ],
      ),
    );
  }

  // Helper to add to cart
  Future<void> _addToCart({
    required BuildContext context,
    required String productId,
    required String offerLabel,
    required double price,
    required int qty,
    required String type,
  }) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      return;
    }
   
    try {
      // Check if product+offer already exists in cart
      final cartQuery = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('cart')
          .where('productId', isEqualTo: productId)
          .where('stationOwnerId', isEqualTo: widget.stationOwnerId)
          .where('offerLabel', isEqualTo: offerLabel)
          .limit(1)
          .get();

      if (cartQuery.docs.isNotEmpty) {
        // Update quantity if exists
        final cartDoc = cartQuery.docs.first;
        final prevQty = (cartDoc['quantity'] ?? 1) as int;
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('cart')
            .doc(cartDoc.id)
            .update({
          'quantity': prevQty + qty,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new cart item

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('cart')
            .add({
          'productId': productId,
          'stationOwnerId': widget.stationOwnerId,
          'name': '$type - $offerLabel',
          'offerLabel': offerLabel,
          'price': price,
          'quantity': qty,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }

  // Supabase compliance file fetching
  List<dynamic> uploadedFiles = [];
  bool isLoading = false;

  Future<void> fetchComplianceFiles(String docId) async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await Supabase.instance.client.storage
          .from('compliance_docs')
          .list(path: 'uploads/$docId');
      setState(() {
        uploadedFiles = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching files from Supabase: $e');
    }
  }


}

class ComplianceFilesDialog extends StatefulWidget {
  final String stationOwnerDocId;
  const ComplianceFilesDialog({super.key, required this.stationOwnerDocId});

  @override
  State<ComplianceFilesDialog> createState() => _ComplianceFilesDialogState();
}

class _ComplianceFilesDialogState extends State<ComplianceFilesDialog> {
  List<dynamic> uploadedFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchComplianceFiles(widget.stationOwnerDocId);
  }

  Future<void> fetchComplianceFiles(String docId) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('compliance_docs')
          .list(path: 'uploads/$docId');
      setState(() {
        uploadedFiles = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getDisplayCategory(String fileName) {
    String lowerCaseFileName = fileName.toLowerCase();
    if (lowerCaseFileName.contains('business') || lowerCaseFileName.contains('mayor')) {
      return 'Business Permit';
    } else if (lowerCaseFileName.contains('sanitary')) {
      return 'Sanitary Permit';
    } else if (lowerCaseFileName.contains('association')) {
      return 'Certificate of Association';
    } else if (lowerCaseFileName.contains('finished') && lowerCaseFileName.contains('bacteriological')) {
      return 'Finished Bacteriological';
    } else if (lowerCaseFileName.contains('source') && lowerCaseFileName.contains('bacteriological')) {
      return 'Source Bacteriological';
    } else if (lowerCaseFileName.contains('finished') && lowerCaseFileName.contains('physical')) {
      return 'Finished Physical';
    }
      else if (lowerCaseFileName.contains('source') && lowerCaseFileName.contains('physical')) {
      return 'Source Bacteriological';
    }
    // Fallback: Clean up the filename a bit by removing extension and replacing underscores
    String nameWithoutExtension = fileName.split('.').first;
    nameWithoutExtension = nameWithoutExtension.replaceAll('_', ' ').replaceAll('-', ' ');
    // Capitalize first letter of each word
    return nameWithoutExtension.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _showFileDialog(dynamic file, String fileUrl, bool isImage, bool isPdf, bool isWord) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            height: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: isImage
                        ? Image.network(
                            fileUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Failed to load image'),
                                ),
                          )
                        : isPdf
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 64),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open PDF'),
                                    onPressed: () async {
                                      if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                        await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not open file')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )
                            : isWord
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.description, color: Colors.blue, size: 64),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Open Document'),
                                        onPressed: () async {
                                          if (await canLaunchUrl(Uri.parse(fileUrl))) {
                                            await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Could not open file')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : const Text('Unsupported file type', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : uploadedFiles.isEmpty
            ? const Center(child: Text('No uploaded compliance files found.'))
            : ListView.builder(
                itemCount: uploadedFiles.length,
                itemBuilder: (context, index) {
                  final file = uploadedFiles[index];
                  final fileUrl = Supabase.instance.client.storage
                      .from('compliance_docs')
                      .getPublicUrl('uploads/${widget.stationOwnerDocId}/${file.name}');
                  final extension = file.name.split('.').last.toLowerCase();
                  final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
                  final isPdf = extension == 'pdf';
                  final isWord = extension == 'doc' || extension == 'docx';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: ListTile(
                      leading: isImage
                          ? const Icon(Icons.image, color: Colors.blue)
                          : isPdf
                              ? const Icon(Icons.picture_as_pdf, color: Colors.red)
                              : isWord
                                  ? const Icon(Icons.description, color: Colors.blue)
                              : const Icon(Icons.insert_drive_file, color: Colors.grey), // Default icon
                      title: Text(_getDisplayCategory(file.name), style: const TextStyle(fontSize: 14)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _showFileDialog(file, fileUrl, isImage, isPdf, isWord);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                        child: const Text('View', style: TextStyle(color: Colors.blue)),
                      ),
                    ),
                  );
                },
              );
  }
}


class StationsScreen extends StatefulWidget {
  StationsScreen({super.key});

  @override
  _StationsScreenState createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  List<Map<String, dynamic>> _allStations = [];

  Future<List<Map<String, dynamic>>> _getAllStations({double? customerLat, double? customerLon}) async {
    final QuerySnapshot stationsSnapshot = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('status', isEqualTo: 'approved')
        .get();

    if (stationsSnapshot.docs.isEmpty) {
      throw Exception('No stations found.');
    }

    final List<Map<String, dynamic>> stations = stationsSnapshot.docs.map((station) {
      final double? stationLat = station['location']?['latitude'];
      final double? stationLon = station['location']?['longitude'];
      double? distance;
      if (customerLat != null && customerLon != null && stationLat != null && stationLon != null) {
        distance = _calculateDistance(
          customerLat,
          customerLon,
          stationLat,
          stationLon,
        );
      }
      return {
        'name': station['stationName'],
        'distance': distance,
        'address': station['address'],
        'stationOwnerId': station.id,
        'latitude': stationLat,
        'longitude': stationLon,
        'firstName': station['firstName'] ?? '',
        'lastName': station['lastName'] ?? '',
      };
    }).toList();

    // If distance is available, sort by distance
    if (customerLat != null && customerLon != null) {
      stations.sort((a, b) {
        final aDist = a['distance'] ?? double.infinity;
        final bDist = b['distance'] ?? double.infinity;
        return aDist.compareTo(bDist);
      });
    }
    return stations;
  }

  Future<void> _fetchStations() async {
    try {
      final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
      final firebase_auth.User? user = auth.currentUser;
      double? customerLat;
      double? customerLon;

      if (user != null) {
        final customerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();

        final defaultAddressId = customerDoc.data()?['defaultAddressId'];
        if (defaultAddressId != null && defaultAddressId != '') {
          final defaultAddressDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .collection('address')
              .doc(defaultAddressId)
              .get();

          if (defaultAddressDoc.exists) {
            customerLat = defaultAddressDoc['latitude'];
            customerLon = defaultAddressDoc['longitude'];
          }
        }
      }
      final stations = await _getAllStations(customerLat: customerLat, customerLon: customerLon);
      setState(() {
        _allStations = stations;
      });
    } catch (e) {
      // Handle error
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<String> _getCustomerName() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user != null) {
      final DocumentSnapshot customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (customerDoc.exists) {
        return customerDoc['firstName'] ?? 'Customer';
      }
    }
    return 'Customer';
  }

  @override
  void initState() {
    super.initState();
    _fetchStations();
    _searchController.addListener(() {
      _searchQueryNotifier.value = _searchController.text.toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getCustomerName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Stack(
            children: [

              // Main scrollable content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 120), // Space for the fixed header
                  // --- Start: Custom Search & Filter Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                suffixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                              ),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filter button
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                // TODO: Add filter logic here
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Text(
                                      'Filter',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.tune, color: Colors.blue.shade700, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // --- End: Custom Search & Filter Bar ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "All Stations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, child) {
                        final filteredStations = _allStations.where((station) {
                          return station['name']
                              .toLowerCase()
                              .contains(searchQuery);
                        }).toList();

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredStations.length,
                                                   itemBuilder: (context, index) {
                            final station = filteredStations[index];
                            final ownerFirstName = station['firstName'] ?? '';
                            final ownerLastName = station['lastName'] ?? '';
                            (ownerFirstName + ' ' + ownerLastName).trim();
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 6,
                              margin: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFF1565C0),
                                          child: Icon(Icons.local_drink, color: Colors.white),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            station['name'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D47A1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            station['address'],
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (station['distance'] != null)
                                      Row(
                                        children: const [
                                          Icon(Icons.access_time, size: 16, color: Colors.black54),
                                          SizedBox(width: 4),
                                          Text(
                                            "Operating Hours 8:00 AM - 7:00 PM",
                                            style: TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(5, (i) => const Icon(Icons.star, size: 16, color: Colors.amber)),
                                        ),
                                        const Spacer(),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => StationDetailsScreen(
                                                  stationName: station['name'],
                                                  ownerName: 'Owner Name',
                                                  address: station['address'],
                                                  stationOwnerId: station['stationOwnerId'],
                                                  latitude: station['latitude'],
                                                  longitude: station['longitude'],
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.shopping_cart, size: 16, color: Colors.white),
                                          label: const Text("Order"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1565C0),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              // --- Start: Fixed-position logo and header (copied from StationsScreen) ---
              Positioned(
                top: 20,
                left: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(
                      child: Image.asset(
                        'assets/logo.png', // Place your logo at this path
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SizedBox(height: 18),
                        Text(
                          "H₂OGO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Color(0xFF1565C0),
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Where safety meets efficiency.",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3A7CA5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart, color: Colors.black),
                      onPressed: () { 
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyCartScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.black),
                      onPressed: () {
                        // Navigate to settings screen
                      },
                    ),
                  ],
                ),
              ),
              // --- End: Fixed-position logo and header ---
            ],
          ),
        );
      },
    );
  }
}


class OrdersScreen extends StatelessWidget {
  OrdersScreen({super.key});

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy – hh:mm a');

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user == null) throw Exception('User not logged in.');

    final QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .get();

    return ordersSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'orderId': doc.id,
        'station': data['stationOwnerId'] ?? 'Unknown Station',
        'productOffer': data['productOffer'] ?? 'Unknown Product',
        'totalPrice': data['totalPrice'] ?? 0.0,
        'status': data['status'] ?? 'Unknown Status',
        'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
      };
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_top;
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final orders = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Stack(
            children: [

              // Main scrollable content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 120), // Space for the fixed header
                  // --- Start: Custom Header (copied from StationsScreen) ---
                  // (Header is now handled by the Stack below)
                  // --- End: Custom Header ---
                 
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "My Orders",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: orders.isEmpty
                        ? const Center(
                            child: Text(
                              'No orders found.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              final statusColor = _getStatusColor(order['status']);
                              final statusIcon = _getStatusIcon(order['status']);
                              final formattedDate = _dateFormat.format(order['timestamp']);

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.local_shipping, color: Colors.blue),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Order ID: ${order['orderId']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.storefront, size: 18, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Station: ${order['station']}',
                                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.local_drink, size: 18, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Product: ${order['productOffer']}',
                                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(statusIcon, size: 18, color: statusColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Status: ${order['status']}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Date: $formattedDate',
                                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.monetization_on, size: 18, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Total: ₱${order['totalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                                              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              // --- Start: Fixed-position logo and header (copied from StationsScreen) ---
              Positioned(
                top: 20,
                left: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(
                      child: Image.asset(
                        'assets/logo.png', // Place your logo at this path
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SizedBox(height: 18),
                        Text(
                          "H₂OGO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Color(0xFF1565C0),
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Where safety meets efficiency.",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3A7CA5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart, color: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyCartScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.black),
                      onPressed: () {
                        // Navigate to settings screen
                      },
                    ),
                  ],
                ),
              ),
              // --- End: Fixed-position logo and header ---
            ],
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Map<String, dynamic>> _getProfileData() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    final firebase_auth.User? user = auth.currentUser;

    if (user != null) {
      final DocumentSnapshot customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();

      if (customerDoc.exists) {
        return {
          'firstName': customerDoc['firstName'] ?? '',
        };
      }
    }
    return {
      'firstName': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getProfileData(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final stationName = data['firstName'] ?? '';


        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false, // Remove back button
            backgroundColor: const Color(0xFF1565C0), // Dark blue header
            title: Row(
              children: const [
                Icon(Icons.person, color: Colors.white), // Profile icon
                SizedBox(width: 8),
                Text(
                  'Profile',
                  style: TextStyle(color: Colors.white), // Set text color to white
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  color: const Color(0xFF1565C0), // Dark blue background
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 30, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stationName.isNotEmpty ? stationName : 'No Station Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // My Account Section
                _buildSectionTitle('My Account'),
                _buildListTile(Icons.security, 'Account & Security', context),
                _buildListTile(Icons.location_on, 'My Addresses', context),
                _buildListTile(Icons.account_balance_wallet, 'Bank Accounts/Cards', context),
                const SizedBox(height: 16),
                // Settings Section
                _buildSectionTitle('Settings'),
                _buildListTile(Icons.lock, 'Change Password', context),
                _buildListTile(Icons.notifications, 'Notification Preferences', context),
                _buildListTile(Icons.language, 'Language', context),
                const SizedBox(height: 16),
                // Support Section
                _buildSectionTitle('Support'),
                _buildListTile(Icons.help, 'Help Centre', context),
                _buildListTile(Icons.policy, 'Policies', context),
                _buildListTile(Icons.info, 'About', context),
                _buildListTile(Icons.logout, 'Log Out', context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: () async {
          if (title == 'My Addresses') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MyAddressesScreen()),
            );
          } else if (title == 'Log Out') {
            await firebase_auth.FirebaseAuth.instance.signOut();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          }
          // Handle other tiles if needed
        },
      ),
    );
  }
}

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  _MyAddressesScreenState createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  String? _defaultAddressId;

  @override
  void initState() {
    super.initState();
    _fetchDefaultAddress();
  }

  Future<void> _fetchDefaultAddress() async {
    final user = _auth.currentUser;
    if (user != null) {
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      setState(() {
        _defaultAddressId = customerDoc.data()?['defaultAddressId'];
      });
    }
  }

  Future<void> _setDefaultAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .update({'defaultAddressId': addressId});
      setState(() {
        _defaultAddressId = addressId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0), // Dark blue header
        title: const Text(
          'My Addresses',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: user == null
          ? const Center(child: Text('No user logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(user.uid)
                  .collection('address')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No addresses found.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                final addresses = snapshot.data!.docs;
                QueryDocumentSnapshot? defaultAddress;
                List<QueryDocumentSnapshot> otherAddresses = [];
                for (var address in addresses) {
                  if (address.id == _defaultAddressId) {
                    defaultAddress = address;
                  } else {
                    otherAddresses.add(address);
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (defaultAddress != null)
                      _buildAddressCard(
                        defaultAddress,
                        isDefault: true,
                        user: user,
                      ),
                    ...otherAddresses.map((address) => _buildAddressCard(
                          address,
                          isDefault: false,
                          user: user,
                        )),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddAddressScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Address'),
      ),
    );
  }

  Widget _buildAddressCard(
      QueryDocumentSnapshot address, {
      required bool isDefault,
      required firebase_auth.User user,
    }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Icon(
          Icons.location_on,
          color: isDefault ? Colors.green : const Color(0xFF1565C0),
          size: 32,
        ),
        title: Text(
          address['address'] ?? 'Unknown Address',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: isDefault
            ? const Text(
                'Default Address',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(user.uid)
                    .collection('address')
                    .doc(address.id)
                    .delete();
                if (isDefault) {
                  await _setDefaultAddress('');
                }
              },
            ),
            if (!isDefault)
              ElevatedButton(
                onPressed: () => _setDefaultAddress(address.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  'Set Default',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  _AddAddressScreenState createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final TextEditingController _addressController = TextEditingController();
  LatLng? _selectedLocation;

  Future<void> _selectLocation(BuildContext context) async {
    LatLng? result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _fetchAddress(result);
      });
    }
  }

  Future<void> _fetchAddress(LatLng position) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _addressController.text = data['display_name'] ?? 'Address not found';
        });
      } else {
        setState(() {
          _addressController.text = 'Failed to fetch address';
        });
      }
    } catch (e) {
      setState(() {
        _addressController.text = 'Error fetching address';
      });
    }
  }

  Future<void> _saveAddress() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && _addressController.text.isNotEmpty) {
      final addressData = {
        'address': _addressController.text,
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('address')
          .add(addressData);

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('Add Address'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'Enter address or select on map',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _selectLocation(context),
              icon: const Icon(Icons.map),
              label: const Text('Select Location on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveAddress,
              child: const Text('Save Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _currentPosition = LatLng(10.3157, 123.8854); // Default to Cebu City
  String _currentAddress = "Loading address...";

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchAddress(LatLng position) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentAddress = data['display_name'] ?? 'Address not found';
        });
      } else {
        setState(() {
          _currentAddress = 'Failed to fetch address';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Error fetching address';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('Pick Location'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _currentPosition = point;
                  _currentAddress = "Loading address...";
                });
                _fetchAddress(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
             
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _currentAddress,
                  style: const TextStyle(
                    fontSize: 16,

                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: () {
          Navigator.of(context).pop(_currentPosition);
        },
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
