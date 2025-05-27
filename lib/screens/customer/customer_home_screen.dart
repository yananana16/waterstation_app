import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import '../login_screen.dart';
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = false; // Add loading state
  final FirebaseAuth auth = FirebaseAuth.instance;
  User? user;

  final List<Widget> _screens = [
    const HomeScreen(),
    NotificationsScreen(), // Changed from DeliveryScreen to NotificationsScreen
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
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications), // Changed icon to notifications
            label: 'Notifications', // Changed label to Notifications
          ),
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

  Future<String> _getCustomerName() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

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
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    if (user == null) throw Exception('User not logged in.');

    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();

    final defaultAddressId = customerDoc.data()?['defaultAddressId'];
    if (defaultAddressId == null) throw Exception('No default address set.');

    final defaultAddressDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .collection('address')
        .doc(defaultAddressId)
        .get();

    if (!defaultAddressDoc.exists) throw Exception('Default address not found.');

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
        String displayName = 'Customer';
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

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('No nearby stations found.')),
              );
            }

            final stations = snapshot.data!;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1565C0),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Welcome, $displayName!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () {
                            // Navigate to settings screen
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Recommended Stations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: stations.length,
                      itemBuilder: (context, index) {
  final station = stations[index];
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
          Row(
            children: [
              const Icon(Icons.directions, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${station['distance'].toStringAsFixed(2)} km away',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StationDetailsScreen(
                      stationName: station['name'],
                      ownerName: 'Owner Name', // Update if available
                      address: station['address'],
                      stationOwnerId: station['stationOwnerId'],
                      latitude: station['latitude'],
                      longitude: station['longitude'],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
              label: const Text(
                'View Details',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
            );
          },
        );
      },
    );
  }
}
class MyCartScreen extends StatelessWidget {
  const MyCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0), // Dark blue header
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Handle edit action
            },
            child: const Text(
              'Edit',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cart items
          Expanded(
            child: ListView.builder(
              itemCount: 2, // Number of items in the cart
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    leading: Checkbox(
                      value: true,
                      onChanged: (value) {
                        // Handle checkbox toggle
                      },
                    ),
                    title: const Text(
                      'AQUA SURE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Slim Container'),
                        Text(
                          '₱ 35.00',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            // Handle decrease quantity
                          },
                        ),
                        const Text('1'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            // Handle increase quantity
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₱ 70.00',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    // Handle checkout
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0), // Dark blue button
                  ),
                  child: const Text('Check Out (1)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  Future<String> _getCustomerName() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

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
        String displayName = 'Customer';
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          displayName = snapshot.data!;
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false, // Remove back button
            backgroundColor: const Color(0xFF1565C0), // Dark blue header
            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 10),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyCartScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                const Icon(Icons.notifications, color: Colors.white),
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

  Future<void> _placeOrder(BuildContext context, String productOffer, String stationOwnerId) async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final User? user = auth.currentUser;

      if (user != null) {
        // Generate a custom OrderID
        final String orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 5)}';

        final orderData = {
          'orderId': orderId, // Use the custom OrderID
          'customerId': user.uid,
          'productOffer': productOffer,
          'status': 'Pending',
          'timestamp': FieldValue.serverTimestamp(),
          'stationOwnerId': stationOwnerId,
        };

        // Add order to the global orders collection
        await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderData);

        // Add order to the station owner's orders subcollection
        await FirebaseFirestore.instance
            .collection('station_owners')
            .doc(stationOwnerId)
            .collection('orders')
            .doc(orderId)
            .set(orderData);

        // Show loading indicator
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
                  CircularProgressIndicator(color: Colors.green), // Loading indicator
                  SizedBox(height: 20),
                  Text(
                    "Processing Order...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );

        // Wait for 1 second, then close the dialog and navigate back
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(); // Close the dialog
        Navigator.of(context).pop(); // Go back to the homepage

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Order Placed Successfully!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Thank you for your order. You will receive a notification once it is processed.",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0), // Dark blue button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );


      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        elevation: 4,
      ),
      body: Column(
        children: [
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
                  Text('Owner: ${widget.ownerName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Address: ${_dynamicAddress ?? "Loading..."}',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
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
                      // Check if products collection exists or has data
                      if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No products available.'),
                          ),
                        );
                      }

                      final products = snapshot.data!.docs;
                      // Filter out products without productOffer key
                      final validProducts = products.where((product) {
                        final data = product.data() as Map<String, dynamic>?;
                        return data != null && data.containsKey('productOffer') && data['productOffer'] != null;
                      }).toList();
                      if (validProducts.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No products available.'),
                          ),
                        );
                      }
                      return Column(
                        children: validProducts.map((product) {
                          final data = product.data() as Map<String, dynamic>;
                          final productOffer = data['productOffer'] ?? 'N/A';
                          final waterType = data['waterType'] ?? 'N/A';
                          final gallon = data['gallon'] == true ? 'Yes' : 'No';
                          final delivery = data['deliveryAvailable'] ?? 'No';

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
                                    productOffer,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text("Water Type: $waterType"),
                                  Text("Gallon: $gallon"),
                                  Text("Delivery: $delivery"),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _placeOrder(context, productOffer, widget.stationOwnerId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1565C0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text("Order Now"),
                                    ),
                                  )
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

  Future<List<Map<String, dynamic>>> _getNearestStations() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    if (user == null) throw Exception('User not logged in.');

    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();

    final defaultAddressId = customerDoc.data()?['defaultAddressId'];
    if (defaultAddressId == null) throw Exception('No default address set.');

    final defaultAddressDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .collection('address')
        .doc(defaultAddressId)
        .get();

    if (!defaultAddressDoc.exists) throw Exception('Default address not found.');

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
    return stations;
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
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

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

  Future<void> _fetchStations() async {
    try {
      final stations = await _getNearestStations();
      setState(() {
        _allStations = stations;
      });
    } catch (e) {
      // Handle error
    }
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
        String displayName = 'Customer';
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          displayName = snapshot.data!;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Welcome, $displayName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        // Navigate to settings screen
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search stations...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFE3F2FD),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                                Row(
                                  children: [
                                    const Icon(Icons.directions, size: 18, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${station['distance'].toStringAsFixed(2)} km away',
                                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StationDetailsScreen(
                                            stationName: station['name'],
                                            ownerName: 'Owner Name', // Update if available
                                            address: station['address'],
                                            stationOwnerId: station['stationOwnerId'],
                                            latitude: station['latitude'],
                                            longitude: station['longitude'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                    label: const Text(
                                      'View Details',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
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
        );
      },
    );
  }
}

class OrdersScreen extends StatelessWidget {
  OrdersScreen({super.key});

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy – hh:mm a');

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: const Text(
                  'My Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      children: const [
                        Text(
                          'Dianna Souribio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Brgy. Duyan-duyan\nSanta Barbara, Iloilo, Philippines\n(+63) 912 345 6789',
                          style: TextStyle(color: Colors.white, fontSize: 14),
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
            await FirebaseAuth.instance.signOut();
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
      required User user,
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
    final user = FirebaseAuth.instance.currentUser;
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
    _fetchAddress(_currentPosition);
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
