import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:Hydrify/screens/login_screen.dart';

class StationHomeScreen extends StatefulWidget {
  const StationHomeScreen({super.key});

  @override
  _StationHomeScreenState createState() => _StationHomeScreenState();
}

class _StationHomeScreenState extends State<StationHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    ComplianceScreen(),
    OrdersScreen(),
    const InventoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hydrify'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            icon: Icon(Icons.assignment),
            label: 'Compliance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage your water station easily',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                Icon(Icons.water_drop, color: Colors.white, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildGridItem(Icons.assignment, 'Compliance'),
              _buildGridItem(Icons.shopping_cart, 'Orders'),
              _buildGridItem(Icons.inventory, 'Inventory'),
              _buildGridItem(Icons.person, 'Profile'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String title) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue.shade700),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class ComplianceScreen extends StatelessWidget {
  ComplianceScreen({super.key});

  // Map of compliance categories with submission labels and timeframes
  final Map<String, Map<String, String>> complianceCategories = {
    'finished_bacteriological': {
      'label': 'Finished Product - Bacteriological',
      'time': 'Every Month',
    },
    'source_bacteriological': {
      'label': 'Source/Deep Well - Bacteriological',
      'time': 'Every 6 Months',
    },
    'source_physical_chemical': {
      'label': 'Source/Deep Well - Physical-Chemical',
      'time': 'Every 6 Months',
    },
    'finished_physical_chemical': {
      'label': 'Finished Product - Physical-Chemical',
      'time': 'Every 6 Months',
    },
    'business_permit': {
      'label': 'Business Permit (BPLO)',
      'time': 'Every 20th of January',
    },
    'dti_cert': {
      'label': 'DTI Certification',
      'time': 'Once',
    },
    'municipal_clearance': {
      'label': 'Municipal Environment and Natural Resources',
      'time': 'Once',
    },
    'retail_plan': {
      'label': 'Plan of the Retail Water Station',
      'time': 'Once',
    },
    'drinking_site_clearance': {
      'label': 'Drinking Water Site Clearance (Local Health Officer)',
      'time': 'Once',
    },
  };

  // Helper function to calculate the next submission date based on time
  String getNextSubmissionDate(String timeFrame, DateTime? lastSubmitted) {
    if (lastSubmitted == null) return 'Not Submitted Yet';

    switch (timeFrame) {
      case 'Every Month':
        return DateFormat('yyyy-MM-dd').format(lastSubmitted.add(Duration(days: 30)));
      case 'Every 6 Months':
        return DateFormat('yyyy-MM-dd').format(lastSubmitted.add(Duration(days: 182))); // ~6 months
      case 'Every 20th of January':
        return DateFormat('yyyy-MM-dd').format(DateTime(lastSubmitted.year + 1, 1, 20));
      case 'Once':
        return 'Passed';
      default:
        return 'Unknown Submission Time';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Example last submission dates (in a real app, you'd fetch these from your database)
    final Map<String, DateTime?> lastSubmissionDates = {
      'finished_bacteriological': DateTime(2025, 3, 3),
      'source_bacteriological': DateTime(2025, 3, 3),
      'source_physical_chemical': DateTime(2025, 3, 3),
      'finished_physical_chemical': DateTime(2025, 3, 3),
      'business_permit': DateTime(2025, 1, 20),
      'dti_cert': DateTime(2025, 3, 3),
      'municipal_clearance': DateTime(2025, 3, 3),
      'retail_plan': DateTime(2025, 3, 3),
      'drinking_site_clearance': DateTime(2025, 3, 3),
    };

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compliance Categories',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // List to display each compliance category
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complianceCategories.length,
              itemBuilder: (context, index) {
                final category = complianceCategories.keys.elementAt(index);
                final label = complianceCategories[category]?['label'];
                final time = complianceCategories[category]?['time'];
                final lastSubmitted = lastSubmissionDates[category];

                // Get next submission date
                final nextSubmissionDate = getNextSubmissionDate(time!, lastSubmitted);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Make text content more flexible
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label!,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,  // Prevent overflow
                                maxLines: 1,
                              ),
                              Text(
                                'Time: $time',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,  // Prevent overflow
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          nextSubmissionDate,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class OrdersScreen extends StatelessWidget {
  OrdersScreen({super.key});

  // Firestore collection reference for orders and users
  final CollectionReference ordersRef = FirebaseFirestore.instance.collection('orders');
  final CollectionReference usersRef = FirebaseFirestore.instance.collection('users');

  // Function to confirm an order by changing the status to 'confirmed'
  Future<void> confirmOrder(String orderID) async {
    try {
      await ordersRef.doc(orderID).update({'orderStatus': 'confirmed'});
    } catch (e) {
      print('Error confirming order: $e');
    }
  }

  // Function to mark an order as delivered by changing the status to 'delivered'
  Future<void> deliverOrder(String orderID) async {
    try {
      await ordersRef.doc(orderID).update({'orderStatus': 'delivered'});
    } catch (e) {
      print('Error marking order as delivered: $e');
    }
  }

  // Get the customUID of the logged-in user from the users collection
  Future<String?> getCustomUID() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await usersRef.doc(user.uid).get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          return userData['customUID'];  // Assuming 'customUID' is stored in the user document
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<String?>(
          future: getCustomUID(),
          builder: (context, uidSnapshot) {
            if (uidSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (uidSnapshot.hasError || !uidSnapshot.hasData) {
              return const Center(child: Text('Error fetching user customUID.'));
            }

            String? customUID = uidSnapshot.data;

            return StreamBuilder<QuerySnapshot>(
              stream: ordersRef.where('customUID', isEqualTo: customUID).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading orders'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }

                // Separate orders by status
                var pendingOrders = snapshot.data!.docs.where((order) => order['orderStatus'] == 'pending').toList();
                var confirmedOrders = snapshot.data!.docs.where((order) => order['orderStatus'] == 'confirmed').toList();
                var deliveredOrders = snapshot.data!.docs.where((order) => order['orderStatus'] == 'delivered').toList();

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Display Pending Orders
                      if (pendingOrders.isNotEmpty) ...[
                        const Text('Pending Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Horizontal scroll
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Order ID')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Total Price')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: pendingOrders.map<DataRow>((order) {
                              return DataRow(cells: [
                                DataCell(Text(order['orderID'])),
                                DataCell(Text(order['quantity'].toString())),
                                DataCell(Text(order['totalPrice'].toString())),
                                DataCell(
                                  ElevatedButton(
                                    onPressed: () => confirmOrder(order['orderID']),
                                    child: const Text('Confirm'),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Display Confirmed Orders
                      if (confirmedOrders.isNotEmpty) ...[
                        const Text('Confirmed Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Horizontal scroll
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Order ID')),
                              DataColumn(label: Text('Station Name')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Total Price')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: confirmedOrders.map<DataRow>((order) {
                              return DataRow(cells: [
                                DataCell(Text(order['orderID'])),
                                DataCell(Text(order['stationName'])),
                                DataCell(Text(order['quantity'].toString())),
                                DataCell(Text(order['totalPrice'].toString())),
                                DataCell(
                                  ElevatedButton(
                                    onPressed: () => deliverOrder(order['orderID']),
                                    child: const Text('Delivered'),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Display Delivered Orders
                      if (deliveredOrders.isNotEmpty) ...[
                        const Text('Delivered Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal, // Horizontal scroll
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Order ID')),
                              DataColumn(label: Text('Station Name')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Total Price')),
                            ],
                            rows: deliveredOrders.map<DataRow>((order) {
                              return DataRow(cells: [
                                DataCell(Text(order['orderID'])),
                                DataCell(Text(order['stationName'])),
                                DataCell(Text(order['quantity'].toString())),
                                DataCell(Text(order['totalPrice'].toString())),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Inventory Section', style: TextStyle(fontSize: 24)),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User _user;

  // Profile fields
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _status = 'Pending Approval'; // You can change this dynamically based on the user's status
  String _phone = '';
  String _stationName = '';

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    _fetchUserProfile();
  }

  // Fetch user profile from Firestore
  void _fetchUserProfile() async {
    DocumentSnapshot userProfile = await _firestore.collection('users').doc(_user.uid).get();
    setState(() {
      _firstName = userProfile['firstName'] ?? '';
      _lastName = userProfile['lastName'] ?? '';
      _email = userProfile['email'] ?? _user.email ?? '';
      _status = userProfile['status'] ?? 'Pending Approval';
      _phone = userProfile['phone'] ?? '';
      _stationName = userProfile['stationName'] ?? ''; 
    });
  }

  // Sign out the user
  Future<void> _logout() async {
  await _auth.signOut();
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => LoginScreen()),
    (Route<dynamic> route) => false,
  );
}


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text('Status: $_status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Text('Station Name: $_stationName', style: const TextStyle(fontSize: 18)),
          const SizedBox(height:20),
          Text('First Name: $_firstName', style: const TextStyle(fontSize: 18)),
          Text('Last Name: $_lastName', style: const TextStyle(fontSize: 18)),
          Text('Email: $_email', style: const TextStyle(fontSize: 18)),
          Text('Phone: $_phone', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
