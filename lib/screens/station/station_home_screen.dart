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
      body: Container(
        color: Colors.white, // Set the entire page background to white
        child: _screens[_currentIndex],
      ),
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
            icon: Icon(Icons.assignment_turned_in),
            label: 'Compliance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
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
    return Container(
      color: Colors.white, // Set the background color to white
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row with Logo, "H2Go" Text, and Icons
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/logo.png', height: 70), // Adjusted logo size
                      const SizedBox(width: 15), // Increased spacing
                      const Text(
                        'H2OGo',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue), // Slightly larger text
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.blue),
                        onPressed: () {
                          // Add notification functionality
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blue),
                        onPressed: () {
                          // Add settings functionality
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, color: Colors.blue),
                        onPressed: () {
                          // Add user profile functionality
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Adjusted spacing below the top row

            // Logo and Welcome Section
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // Allow horizontal scrolling to prevent overflow
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/undraw_home-screen_63eq-removebg-preview 1.png', height: 250), // Illustration
                    const SizedBox(width: 20), // Spacing between image and text
                    Container(
                      color: Colors.white, // White background for better visibility
                      padding: const EdgeInsets.all(8.0), // Padding around the text
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                        children: const [
                          Text(
                            'Welcome!',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          SizedBox(height: 5), // Spacing between "Welcome!" and "User"
                          Text(
                            'User',
                            style: TextStyle(fontSize: 20, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card for Daily Sales and Monthly Revenue
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.blue.shade50, // Updated background color
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quench-O Purified Drinking Water',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(DateTime.now()),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Daily Sales', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                height: 100,
                                color: Colors.blue.shade100, // Placeholder for graph
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Monthly Revenue', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                height: 100,
                                color: Colors.blue.shade100, // Placeholder for graph
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Reminders Section
            const Text('Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildReminderCard(Icons.warning, 'Time to backwash! You’ve filled 100-200 containers.'),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(IconData icon, String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue.shade700),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}

class ComplianceScreen extends StatelessWidget {
  ComplianceScreen({super.key});

  final List<Map<String, String>> complianceResults = [
    {
      'title': 'March 2025',
      'subtitle': 'Bacteriological Water Analysis',
      'sampleCollected': 'March 3, 2025',
      'resultsReleased': 'March 7, 2025',
      'status': 'Passed',
      'validUntil': 'April 2025',
    },
    {
      'title': 'Physical Water Analysis',
      'subtitle': '',
      'sampleCollected': 'January 16, 2025',
      'resultsReleased': 'January 21, 2025',
      'status': 'Passed',
      'validUntil': 'June 2025',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove the back button
        title: const Text(
          'Compliance',
          style: TextStyle(color: Colors.blue), // Set title font color to blue
        ),
        backgroundColor: Colors.white, // Set app bar background to white
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to black
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Add user profile functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Results',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history),
              label: const Text('View Previous Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: complianceResults.length,
                itemBuilder: (context, index) {
                  final result = complianceResults[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['title']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          if (result['subtitle']!.isNotEmpty)
                            Text(
                              result['subtitle']!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text('Sample Collected: ${result['sampleCollected']}'),
                          Text('Results Released On: ${result['resultsReleased']}'),
                          Text(
                            'Status: ${result['status']}',
                            style: TextStyle(
                              color: result['status'] == 'Passed' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Valid Until: ${result['validUntil']}'),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CertificationScreen()),
                              );
                            },
                            child: const Text(
                              'View Certification',
                              style: TextStyle(color: Colors.blue),
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
      ),
    );
  }
}

class CertificationScreen extends StatelessWidget {
  const CertificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certification'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Bacteriological Water Analysis',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'March 2025',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Quench-O Purified Drinking Water',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '42-A Gustilo St., La Paz, Iloilo City',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Text(
                              'Certification Details Placeholder',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Add functionality to save as PDF if needed
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Save as PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  OrdersScreen({super.key});

  final CollectionReference ordersRef = FirebaseFirestore.instance.collection('orders');

  Future<Map<String, int>> fetchOrderSummary() async {
    QuerySnapshot snapshot = await ordersRef.get();
    int pending = 0, readyForDelivery = 0, todayOrders = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['orderStatus'] == 'pending') pending++;
      if (data['orderStatus'] == 'readyForDelivery') readyForDelivery++;
      if (data['orderDate'] == DateFormat('yyyy-MM-dd').format(DateTime.now())) todayOrders++;
    }

    return {
      'pending': pending,
      'readyForDelivery': readyForDelivery,
      'todayOrders': todayOrders,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove the back button
        title: const Text(
          'Order and Delivery',
          style: TextStyle(color: Colors.blue), // Set title font color to blue
        ),
        backgroundColor: Colors.white, // Set app bar background to white
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to black
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Add user profile functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, int>>(
          future: fetchOrderSummary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Error fetching order summary.'));
            }

            final summary = snapshot.data!;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryCard('Pending Orders', summary['pending'].toString()),
                    _buildSummaryCard('Ready for Delivery', summary['readyForDelivery'].toString()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryCard('Number of Orders Today', summary['todayOrders'].toString(), isFullWidth: true),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(Icons.list, 'Orders', () {
                      // Navigate to Orders List screen
                    }),
                    _buildActionButton(Icons.add, 'Add Order', () {
                      // Navigate to Add Order screen
                    }),
                    _buildActionButton(Icons.local_shipping, 'Deliveries', () {
                      // Navigate to Deliveries screen
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, {bool isFullWidth = false}) {
    return Expanded(
      flex: isFullWidth ? 2 : 1,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.blue.shade50, // Updated background color
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue.shade50,
          ),
          child: Icon(icon, size: 30, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.blue)),
      ],
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  void _showSalesScreen(BuildContext context) {
    String selectedMonth = 'Any';
    String selectedYear = 'Any';

    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
            title: const Text(
              'Sales',
              style: TextStyle(color: Colors.blue),
            ),
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  // Add notification functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // Add settings functionality
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: selectedMonth,
                      items: ['Any', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
                          .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                          .toList(),
                      onChanged: (value) {
                        selectedMonth = value!;
                      },
                    ),
                    DropdownButton<String>(
                      value: selectedYear,
                      items: ['Any', '2023', '2024', '2025', '2026', '2027']
                          .map((year) => DropdownMenuItem(value: year, child: Text(year)))
                          .toList(),
                      onChanged: (value) {
                        selectedYear = value!;
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        selectedMonth = 'Any';
                        selectedYear = 'Any';
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Apply', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.blue.shade50, // Match _buildSalesCard background color
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: const [
                        Text(
                          'Daily Sales',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'P 9540',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSalesCard('Returned Containers', '55'),
                    _buildSalesCard('Number of Orders', '318'),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: List.generate(4, (index) {
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.blue.shade50, // Match _buildSalesCard background color
                        child: ListTile(
                          title: Text('Order No. 0${60 + index}'),
                          subtitle: Text('Quantity: ${[20, 5, 10, 20][index]}'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              // Add view functionality
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('View'),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalesCard(String title, String value) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.blue.shade50, // Updated background color
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)), // Reduced font size
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)), // Reduced font size
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(String title, String value, {bool isFullWidth = false}) {
    return Expanded(
      flex: isFullWidth ? 2 : 1,
      child: Card(
        color: Colors.blue.shade50, // Match card box background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)), // Reduced font size
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.blue)), // Reduced font size
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12), // Reduced padding for closer icons
            backgroundColor: Colors.blue.shade50,
          ),
          child: Icon(icon, size: 28, color: Colors.blue), // Adjusted icon size
        ),
        const SizedBox(height: 6), // Reduced spacing
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.blue)), // Adjusted font size
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove the back button
        title: const Text(
          'Sales and Inventory',
          style: TextStyle(fontSize: 18, color: Colors.blue), // Adjusted font size
        ),
        backgroundColor: Colors.white, // Set app bar background to white
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to black
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Add user profile functionality
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white, // Set the entire page background to white
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Image.asset(
                'assets/Sales and Inventory.png',
                height: 150, // Adjust height as needed
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInventoryCard('Returned Containers', '35'),
                  _buildInventoryCard('Number of Orders', '110'),
                ],
              ),
              const SizedBox(height: 20),
              _buildInventoryCard('Current Number of Containers', '685', isFullWidth: true),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => _showSalesScreen(context),
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12), // Reduced padding for closer icons
                          backgroundColor: Colors.blue.shade50, // Match card box background
                        ),
                        child: const Icon(Icons.bar_chart, size: 28, color: Colors.blue), // Adjusted icon size
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      const Text('Sales', style: TextStyle(fontSize: 12, color: Colors.blue)), // Adjusted font size
                    ],
                  ),
                  _buildActionButton(Icons.inventory, 'Inventory', () {}),
                  _buildActionButton(Icons.report, 'Report', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportScreen()),
                    );
                  }),
                  _buildActionButton(Icons.people, 'Staffs', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StaffsScreen()),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: 'February',
                  items: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
                      .map((month) => DropdownMenuItem(value: month, child: Text(month)))
                      .toList(),
                  onChanged: (value) {
                    // Handle month selection
                  },
                ),
                DropdownButton<String>(
                  value: '2025',
                  items: ['2023', '2024', '2025', '2026', '2027']
                      .map((year) => DropdownMenuItem(value: year, child: Text(year)))
                      .toList(),
                  onChanged: (value) {
                    // Handle year selection
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Handle Save as PDF
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                  label: const Text('Save as PDF', style: TextStyle(color: Colors.blue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Handle Save as Excel
                  },
                  icon: const Icon(Icons.grid_on, color: Colors.blue),
                  label: const Text('Save as Excel', style: TextStyle(color: Colors.blue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Quench-O Purified Drinking Water',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '42-A Gustilo St., La Paz, Iloilo City',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sales Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'As of February 2025',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: 5, // Placeholder for report rows
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              height: 40,
                              color: Colors.grey.shade300,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffsScreen extends StatelessWidget {
  const StaffsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staffs', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to black
      ),
      body: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  DateFormat('hh:mm a').format(DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildStaffSection('Refilling Technician', 3),
                _buildStaffSection('Cashier', 1),
                _buildStaffSection('Delivery Personnel', 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffSection(String title, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity, // Stretch the background to full width
          color: Colors.blue.shade700,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Column(
          children: List.generate(count, (index) {
            return Container(
              width: double.infinity, // Stretch the background to full width
              color: Colors.blue.shade50,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                title: const Text(
                  '',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            );
          }),
        ),
      ],
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
  String _stationName = '';
  String _address = '';
  String _fullName = '';
  String _email = '';

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
      _stationName = userProfile['stationName'] ?? '';
      _address = userProfile['address'] ?? '';
      _fullName = '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}';
      _email = userProfile['email'] ?? _user.email ?? '';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to black
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.store, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Text(
              _stationName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _address,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _fullName,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              _email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _buildProfileButton(Icons.business, 'Edit Business Profile', () {
              // Navigate to Edit Business Profile screen
            }),
            _buildProfileButton(Icons.person, 'Edit User Profile', () {
              // Navigate to Edit User Profile screen
            }),
            _buildProfileButton(Icons.assignment, 'View Accreditation Status', () {
              // Navigate to Accreditation Status screen
            }),
            _buildProfileButton(Icons.lock, 'Change Password', () {
              // Navigate to Change Password screen
            }),
            _buildProfileButton(Icons.logout, 'Log Out', _logout, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileButton(IconData icon, String label, VoidCallback onPressed, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isDestructive ? Colors.red : Colors.blue),
        label: Text(label, style: TextStyle(color: isDestructive ? Colors.red : Colors.blue)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade50,
          minimumSize: const Size(double.infinity, 50),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
