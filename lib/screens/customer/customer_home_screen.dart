import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    const OrdersScreen(),
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
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Header with customer name
              Container(
                padding: const EdgeInsets.all(16.0),
                color: const Color(0xFF1565C0), // Dark blue header
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.person, color: Color(0xFF1565C0)),
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
                    const Icon(Icons.shopping_cart, color: Colors.white),
                    const SizedBox(width: 10),
                    const Icon(Icons.notifications, color: Colors.white),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFE3F2FD), // Light blue background
                  ),
                ),
              ),
              // Station cards
              Expanded(
                child: ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Card(
                      color: const Color(0xFFE3F2FD), // Light blue card background
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AQUA SURE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1), // Darker blue text
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'San Isidro, Jaro, Iloilo City\nOperating Hours: 8:00 AM - 7:00 PM',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    Icon(Icons.star_border, color: Colors.amber, size: 16),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.shopping_cart,
                                    size: 16,
                                    color: Colors.white, // Set icon color to white
                                  ),
                                  label: const Text(
                                    'Order',
                                    style: TextStyle(color: Colors.white), // Set font color to white
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0), // Dark blue button
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
              // Promotional banner
              Container(
                color: const Color(0xFFE3F2FD), // Light blue banner background
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Get 10% off on your\nfirst order!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1), // Darker blue text
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(color: Colors.white), // Set text color to white
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0), // Dark blue button
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final List<Map<String, String>> notifications = [
    {
      'title': 'Security Updates',
      'time': 'Today | 10:30 AM',
      'description': 'We’ve made performance improvements and bug fixes to enhance your experience!',
      'status': 'New',
    },
    {
      'title': 'Password Updated',
      'time': '02 April, 2025 | 11:20 PM',
      'description': 'You have updated your password. Contact the help center if you feel you are not doing it.',
    },
    {
      'title': 'Order Confirmed!',
      'time': '02 April, 2025 | 11:20 PM',
      'description': 'Your order #123 has been confirmed!',
    },
    {
      'title': 'Account Setup Successful!',
      'time': '02 April, 2025 | 06:20 PM',
      'description': 'Your account creation is successful, you can now apply jobs with our services.',
    },
    {
      'title': 'Order Delivered!',
      'time': '03 April, 2025 | 11:20 AM',
      'description': 'Your order #123 has been successfully delivered!',
    },
    {
      'title': 'Order Confirmed!',
      'time': '03 April, 2025 | 11:20 AM',
      'description': 'Your order #123 has been confirmed!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1565C0), // Dark blue header
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
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
                          notification['title']!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (notification.containsKey('status'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['time']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification['description']!,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class StationsScreen extends StatelessWidget {
  StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stations'),
        backgroundColor: const Color(0xFF1565C0), // Dark blue header
      ),
      body: ListView.builder(
        itemCount: 5, // Number of stations
        itemBuilder: (context, index) {
          return Card(
            color: const Color(0xFFE3F2FD), // Light blue card background
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          index == 0 ? 'AQUA SURE' : 'QUENCH-O GUSTILO BRANCH',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1), // Darker blue text
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          index == 0
                              ? 'San Isidro, Jaro, Iloilo City\nOperating Hours: 8:00 AM - 7:00 PM'
                              : 'Gustilo St, La Paz, Iloilo City\nOperating Hours: 7:00 AM - 8:30 PM',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Icon(Icons.star_border, color: Colors.amber, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF1565C0)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.shopping_cart,
                          size: 16,
                          color: Colors.white, // Set icon color to white
                        ),
                        label: const Text(
                          'Order',
                          style: TextStyle(color: Colors.white), // Set font color to white
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0), // Dark blue button
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
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          'Orders Screen',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ),
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
            _buildListTile(Icons.security, 'Account & Security'),
            _buildListTile(Icons.location_on, 'My Addresses'),
            _buildListTile(Icons.account_balance_wallet, 'Bank Accounts/Cards'),
            const SizedBox(height: 16),
            // Settings Section
            _buildSectionTitle('Settings'),
            _buildListTile(Icons.lock, 'Change Password'),
            _buildListTile(Icons.notifications, 'Notification Preferences'),
            _buildListTile(Icons.language, 'Language'),
            const SizedBox(height: 16),
            // Support Section
            _buildSectionTitle('Support'),
            _buildListTile(Icons.help, 'Help Centre'),
            _buildListTile(Icons.policy, 'Policies'),
            _buildListTile(Icons.info, 'About'),
            _buildListTile(Icons.logout, 'Log Out'),
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

  Widget _buildListTile(IconData icon, String title) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: () {
          // Handle navigation or action
        },
      ),
    );
  }
}
