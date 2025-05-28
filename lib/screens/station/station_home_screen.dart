import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:Hydrify/screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- Add this import


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
    InventoryScreen(),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _monthlyRevenue = 0;
  bool _loadingRevenue = true;

  double _totalSales = 0;
  bool _loadingTotalSales = true;

  double _dailySales = 0;
  bool _loadingDailySales = true;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyRevenue();
    _fetchTotalSales();
    _fetchDailySales();
  }

  Future<void> _fetchMonthlyRevenue() async {
  try {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _monthlyRevenue = 0;
        _loadingRevenue = false;
      });
      return;
    }

    // Get the station owner's document
    final query = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      setState(() {
        _monthlyRevenue = 0;
        _loadingRevenue = false;
      });
      return;
    }

    final stationOwnerDocId = query.docs.first.id;

    // Get all sales (because 'date' is stored as String and cannot be filtered in Firestore)
    final salesSnapshot = await FirebaseFirestore.instance
        .collection('station_owners')
        .doc(stationOwnerDocId)
        .collection('sales')
        .get();

    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    double sum = 0;

    for (var doc in salesSnapshot.docs) {
      final data = doc.data();
      final totalSales = data['total_sales'];
      final dateString = data['date'];

      try {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final saleDate = DateTime(year, month, day);

          if (saleDate.isAfter(startOfMonth) || saleDate.isAtSameMomentAs(startOfMonth)) {
            if (totalSales is int) {
              sum += totalSales.toDouble();
            } else if (totalSales is double) {
              sum += totalSales;
            }
          }
        }
      } catch (e) {
        // skip invalid date format
        continue;
      }
    }

    setState(() {
      _monthlyRevenue = sum;
      _loadingRevenue = false;
    });
  } catch (e) {
    setState(() {
      _monthlyRevenue = 0;
      _loadingRevenue = false;
    });
  }
}


  Future<void> _fetchTotalSales() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _totalSales = 0;
          _loadingTotalSales = false;
        });
        return;
      }
      final query = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _totalSales = 0;
          _loadingTotalSales = false;
        });
        return;
      }
      final stationOwnerDocId = query.docs.first.id;
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(stationOwnerDocId)
          .collection('sales')
          .get();

      double sum = 0;
      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final totalSales = data['total_sales'];
        if (totalSales is int) {
          sum += totalSales.toDouble();
        } else if (totalSales is double) {
          sum += totalSales;
        }
      }
      setState(() {
        _totalSales = sum;
        _loadingTotalSales = false;
      });
    } catch (e) {
      setState(() {
        _totalSales = 0;
        _loadingTotalSales = false;
      });
    }
  }

  Future<void> _fetchDailySales() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _dailySales = 0;
          _loadingDailySales = false;
        });
        return;
      }
      final query = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _dailySales = 0;
          _loadingDailySales = false;
        });
        return;
      }
      final stationOwnerDocId = query.docs.first.id;
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(stationOwnerDocId)
          .collection('sales')
          .get();

      final now = DateTime.now();
      final todayString = "${now.month}/${now.day}/${now.year}";

      double sum = 0;
      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final totalSales = data['total_sales'];
        final dateString = data['date'];
        if (dateString == todayString) {
          if (totalSales is int) {
            sum += totalSales.toDouble();
          } else if (totalSales is double) {
            sum += totalSales;
          }
        }
      }
      setState(() {
        _dailySales = sum;
        _loadingDailySales = false;
      });
    } catch (e) {
      setState(() {
        _dailySales = 0;
        _loadingDailySales = false;
      });
    }
  }

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
            Padding(
              padding: const EdgeInsets.only(top: 32.0), // <-- Add top margin here
              child: Center(
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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
                                child: Center(
                                  child: _loadingDailySales
                                      ? const CircularProgressIndicator()
                                      : Text(
                                          '₱${_dailySales.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                ),
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
                                child: Center(
                                  child: _loadingRevenue
                                      ? const CircularProgressIndicator()
                                      : Text(
                                          '₱${_monthlyRevenue.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                ),
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
            const SizedBox(height: 12),
            // --- Total Sales Section ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.blue, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _loadingTotalSales
                          ? const LinearProgressIndicator()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Sales',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₱${_totalSales.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
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

// --- Reusable Custom AppBar Widget ---
class CustomTopBar extends StatelessWidget {
  final String title;
  final bool showProfileIcon;
  final VoidCallback? onProfileTap;
  final List<Widget>? extraActions;
  final double fontSize; // Add fontSize parameter

  const CustomTopBar({
    super.key,
    required this.title,
    this.showProfileIcon = true,
    this.onProfileTap,
    this.extraActions,
    this.fontSize = 26, // Default to 26
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, left: 0, right: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize, // Use the parameter
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
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
              if (showProfileIcon)
                IconButton(
                  icon: const Icon(Icons.person, color: Colors.blue),
                  onPressed: onProfileTap ??
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                ),
              if (extraActions != null) ...extraActions!,
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  String? stationOwnerId;
  List<FileObject> uploadedFiles = [];
  bool isLoading = true;

  // Track which files are expanded (viewed)
  final Set<int> _expandedIndexes = {};

  @override
  void initState() {
    super.initState();
    fetchStationOwnerDocId();
  }

  Future<void> fetchStationOwnerDocId() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('station_owners')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docId = snapshot.docs.first.id;
        setState(() {
          stationOwnerId = docId;
        });

        await fetchComplianceFiles(docId);
      } else {
        setState(() {
          isLoading = false;
        });
        print('No station owner document found for user.');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching station owner ID: $e');
    }
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
      print('Error fetching files from Supabase: $e');
    }
  }

  String _extractCategoryLabel(String fileName, String docId) {
    // Example: abc123_business_permit.pdf -> business_permit
    final prefix = '${docId}_';
    if (fileName.startsWith(prefix)) {
      final rest = fileName.substring(prefix.length);
      final category = rest.split('.').first; // remove extension
      // Convert snake_case to Title Case
      return category
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
    }
    return 'Unknown Category';
  }

  // Dummy status extraction for demonstration (replace with your logic if you have status in metadata)
  String _extractStatus(String fileName) {
    // You can update this logic to extract status from file metadata if available
    // For now, always return "Passed"
    return "Passed";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomTopBar(title: 'Compliance'),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : stationOwnerId == null
                      ? const Center(child: Text('No station owner record found.'))
                      : uploadedFiles.isEmpty
                          ? const Center(child: Text('No uploaded compliance files found.'))
                          : ListView.builder(
                              itemCount: uploadedFiles.length,
                              itemBuilder: (context, index) {
                                final file = uploadedFiles[index];
                                final fileUrl = Supabase.instance.client.storage
                                    .from('compliance_docs')
                                    .getPublicUrl('uploads/$stationOwnerId/${file.name}');

                                final extension = file.name.split('.').last.toLowerCase();
                                final isImage = ['png', 'jpg', 'jpeg'].contains(extension);
                                final isPdf = extension == 'pdf';
                                final isWord = extension == 'doc' || extension == 'docx';

                                final categoryLabel = _extractCategoryLabel(file.name, stationOwnerId!);
                                final status = _extractStatus(file.name);

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          categoryLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          file.name,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Text(
                                              "Status: ",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            Text(
                                              status,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              if (_expandedIndexes.contains(index)) {
                                                _expandedIndexes.remove(index);
                                              } else {
                                                _expandedIndexes.add(index);
                                              }
                                            });
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
                                          child: Text(
                                            _expandedIndexes.contains(index) ? 'Hide File' : 'View File',
                                            style: const TextStyle(color: Colors.blue),
                                          ),
                                        ),
                                        if (_expandedIndexes.contains(index)) ...[
                                          const SizedBox(height: 8),
                                          if (isImage)
                                            Image.network(
                                              fileUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Padding(
                                                    padding: EdgeInsets.all(16.0),
                                                    child: Text('Failed to load image'),
                                                  ),
                                            )
                                          else if (isPdf || isWord)
                                            Row(
                                              children: [
                                                Icon(
                                                  isPdf ? Icons.picture_as_pdf : Icons.description,
                                                  color: isPdf ? Colors.red : Colors.blue,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isPdf ? 'PDF Document' : 'Word Document',
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  icon: const Icon(Icons.open_in_new, color: Colors.blue),
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
                                          else
                                            const Text('Unsupported file type', style: TextStyle(color: Colors.red)),
                                        ],
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

class OrdersScreen extends StatefulWidget {
  OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _orders = [];
        _loading = false;
      });
      return;
    }
    try {
      final query = await _firestore
          .collection('station_owners')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        setState(() {
          _orders = [];
          _loading = false;
        });
        return;
      }
      final stationOwnerDocId = query.docs.first.id;
      final snapshot = await _firestore
          .collection('station_owners')
          .doc(stationOwnerDocId)
          .collection('orders')
          .get();
      setState(() {
        _orders = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _orders = [];
        _loading = false;
      });
    }
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 16, right: 16, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Order and Delivery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.blue),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.blue),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(now),
            style: const TextStyle(fontSize: 14, color: Colors.blue),
          ),
          Text(
            DateFormat('hh:mm a').format(now) + " PST",
            style: const TextStyle(fontSize: 14, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberOfOrdersTodayCard(String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Text(
            "Number of Orders Today:",
            style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  void _navigateToOrdersList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrdersListScreen(orders: _orders, loading: _loading)),
    );
  }

  void _navigateToAddOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddOrderScreen(onOrderAdded: () async {
        await _fetchOrders();
      })),
    );
  }

  void _navigateToDeliveries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeliveriesScreen()),
    );
  }

  Widget _buildCircleButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final pendingOrders = _orders.where((o) => o['status'] == 'Pending').length.toString();
    final readyForDelivery = _orders.where((o) => o['status'] == 'Ready for Delivery').length.toString();
    final ordersToday = _orders.length.toString();

    return Column(
      children: [
        Image.asset(
          'assets/order_delivery_illustration.png',
          height: 140,
        ),
        _buildDateRow(),
        Row(
          children: [
            _buildStatCard('Pending Orders:', pendingOrders),
            _buildStatCard('Ready for Delivery:', readyForDelivery),
          ],
        ),
        _buildNumberOfOrdersTodayCard(ordersToday),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircleButton(Icons.list_alt, "Orders", _navigateToOrdersList),
            _buildCircleButton(Icons.add_circle, "Add Order", _navigateToAddOrder),
            _buildCircleButton(Icons.local_shipping, "Deliveries", _navigateToDeliveries),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomTopBar(
              title: 'Order and Delivery',
              fontSize: 20, // Lower font size for OrdersScreen
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildMainContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- New Screens ---

class OrdersListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final bool loading;
  const OrdersListScreen({super.key, required this.orders, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text('No orders found.'))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: ListTile(
                        title: Text('Order ID: ${order['orderId'] ?? order['id']}'),
                        subtitle: Text('Status: ${order['status'] ?? "Unknown"}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Add functionality for viewing order details
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('View'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class AddOrderScreen extends StatefulWidget {
  final Future<void> Function() onOrderAdded;
  const AddOrderScreen({super.key, required this.onOrderAdded});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    final customer = _customerNameController.text.trim();
    final product = _productController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (product.isEmpty || quantity <= 0 || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final query = await _firestore
            .collection('station_owners')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final stationOwnerDocId = query.docs.first.id;
          await _firestore
              .collection('station_owners')
              .doc(stationOwnerDocId)
              .collection('orders')
              .add({
            'customer': customer,
            'product': product,
            'quantity': quantity,
            'amount': amount,
            'status': 'Pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          _customerNameController.clear();
          _productController.clear();
          _quantityController.clear();
          _amountController.clear();
          await widget.onOrderAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order added!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Order', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Walk-in Order",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: "Customer Name (optional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: "Product",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_drink),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Quantity",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount (₱)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Add Order"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitOrder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const Center(
        child: Text(
          'Deliveries (Coming Soon)',
          style: TextStyle(color: Colors.blue, fontSize: 18),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  // Example data for the dashboard
  final int returnedContainers = 35;
  final int numberOfOrders = 110;
  final int currentContainers = 685;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with title and icons
            Padding(
              padding: const EdgeInsets.only(top: 24.0, left: 16, right: 16, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sales and Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications, color: Colors.black),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Illustration
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.asset(
                'assets/Sales and Inventory.png',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            // Date and Time Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(now),
                    style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(now) + " PST",
                    style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Returned Containers & Number of Orders
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          const Text(
                            "Returned Containers:",
                            style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$returnedContainers',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          const Text(
                            "Number of Orders:",
                            style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$numberOfOrders',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Current Number of Containers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    const Text(
                      "Current Number of Containers:",
                      style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currentContainers',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Quick Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SalesScreen()),
                      );
                    },
                    child: _buildQuickAction(Icons.show_chart, "Sales"),
                  ),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Container Inventory",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.radio_button_checked, color: Colors.blue, size: 32),
                                            const SizedBox(height: 8),
                                            const Text(
                                              "Round Gallon",
                                              style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              "Stock: 48",
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                // Add functionality to add stock for Round Gallon
                                              },
                                              icon: const Icon(Icons.add, size: 18),
                                              label: const Text("Add Stock"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(0, 36),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.crop_square, color: Colors.blue, size: 32),
                                            const SizedBox(height: 8),
                                            const Text(
                                              "Slim Gallon",
                                              style: TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              "Stock: 62",
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                // Add functionality to add stock for Slim Gallon
                                              },
                                              icon: const Icon(Icons.add, size: 18),
                                              label: const Text("Add Stock"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(0, 36),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: _buildQuickAction(Icons.inventory_2, "Inventory"),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProductsScreen()),
                      );
                    },
                    child: _buildQuickAction(Icons.shopping_bag, "Products"),
                  ),
                  _buildQuickAction(Icons.insert_chart, "Report"),
                  _buildQuickAction(Icons.groups, "Staffs"),
                ],
              ),
            ),
            // Spacer to push bottom nav up
            const Spacer(),
            // ...existing code for bottom navigation bar...
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.blue, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// --- Products Screen ---
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
    });
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _products = [];
        _loading = false;
      });
      return;
    }
    final query = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final stationOwnerDocId = query.docs.first.id;
      final snapshot = await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(stationOwnerDocId)
          .collection('products')
          .get();
      setState(() {
        _products = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _loading = false;
      });
    } else {
      setState(() {
        _products = [];
        _loading = false;
      });
    }
  }

  Future<void> _addProduct() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('station_owners')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final stationOwnerDocId = query.docs.first.id;
      await FirebaseFirestore.instance
          .collection('station_owners')
          .doc(stationOwnerDocId)
          .collection('products')
          .add({
        'name': _nameController.text.trim(),
        'type': _typeController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'stock': int.tryParse(_stockController.text.trim()) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      _typeController.clear();
      _priceController.clear();
      _stockController.clear();
      await _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(color: Colors.blue)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: ListTile(
                                leading: const Icon(Icons.shopping_bag, color: Colors.blue),
                                title: Text(product['name'] ?? ''),
                                subtitle: Text(
                                  'Type: ${product['type'] ?? ''}\nPrice: ₱${(product['price'] ?? 0).toString()}\nStock: ${product['stock'] ?? 0}',
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ExpansionTile(
                    title: const Text("Add Product", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.add, color: Colors.blue),
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Product Name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _typeController,
                        decoration: const InputDecoration(
                          labelText: "Type (e.g. Purified, Mineral)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Price",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Stock",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.save),
                          label: const Text("Save Product"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late firebase_auth.User _user;

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomTopBar(title: 'Profile', showProfileIcon: false),
            Expanded(
              child: SingleChildScrollView(
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditBusinessProfileScreen()),
                      );
                    }),
                    _buildProfileButton(Icons.person, 'Edit User Profile', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditUserProfileScreen()),
                      );
                    }),
                    _buildProfileButton(Icons.assignment, 'View Accreditation Status', () {
                      // Navigate to Accreditation Status screen
                    }),
                    _buildProfileButton(Icons.lock, 'Change Password', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      );
                    }),
                    _buildProfileButton(Icons.logout, 'Log Out', _logout, isDestructive: true),
                  ],
                ),
              ),
            ),
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

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  Future<void> _changePassword() async {
    try {
      final user = _auth.currentUser!;
      final cred = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(cred);
      if (_newPasswordController.text == _confirmPasswordController.text) {
        await user.updatePassword(_newPasswordController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.blue), // Set font color to blue
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () {
              // Add notification functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.asset(
              'assets/change_password_illustration.png',
              height: 150,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Enter current password',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.visibility_off),
                  onPressed: () {
                    // Add visibility toggle functionality
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'Enter new password',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.visibility_off),
                  onPressed: () {
                    // Add visibility toggle functionality
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Re-enter new password',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.visibility_off),
                  onPressed: () {
                    // Add visibility toggle functionality
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Change Password',
                style: TextStyle(color: Colors.white), // Set font color to white
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditUserProfileScreen extends StatefulWidget {
  const EditUserProfileScreen({super.key});

  @override
  _EditUserProfileScreenState createState() => _EditUserProfileScreenState();
}

class _EditUserProfileScreenState extends State<EditUserProfileScreen> {
  final _userNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing user data if available
    _userNameController.text = "Name"; // Replace with actual user data
    _contactNumberController.text = "0912 345 6789"; // Replace with actual user data
    _emailController.text = "user@gmail.com"; // Replace with actual user data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.blue),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () {
              // Add notification functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.store, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                // Add functionality to change profile picture
              },
              icon: const Icon(Icons.edit, color: Colors.blue),
              label: const Text(
                'Change Profile Picture',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            _buildEditableField('User Name:', _userNameController),
            const SizedBox(height: 10),
            _buildEditableField('Contact Number:', _contactNumberController),
            const SizedBox(height: 10),
            _buildEditableField('Email:', _emailController),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Add functionality to save changes
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.edit, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class EditBusinessProfileScreen extends StatefulWidget {
  const EditBusinessProfileScreen({super.key});

  @override
  _EditBusinessProfileScreenState createState() => _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productOfferingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing business data if available
    _businessNameController.text = "Quench-O Purified Drinking Water"; // Replace with actual data
    _addressController.text = "42-A Gustilo St., La Paz, Iloilo City"; // Replace with actual data
    _contactNumberController.text = "0912 345 6789"; // Replace with actual data
    _emailController.text = "quench_o@gmail.com"; // Replace with actual data
    _descriptionController.text = "Available Water Types & Pricing\nPurified Water - PHP 25"; // Replace with actual data
    _productOfferingController.text = "Bottles\nSlim"; // Replace with actual data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Profile',
          style: TextStyle(color: Colors.blue),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () {
              // Add notification functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.store, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                // Add functionality to change profile picture
              },
              icon: const Icon(Icons.edit, color: Colors.blue),
              label: const Text(
                'Change Profile Picture',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            _buildEditableField('Business Name:', _businessNameController),
            const SizedBox(height: 10),
            _buildEditableField('Address:', _addressController),
            const SizedBox(height: 10),
            _buildEditableField('Contact Number:', _contactNumberController),
            const SizedBox(height: 10),
            _buildEditableField('Email:', _emailController),
            const SizedBox(height: 10),
            _buildEditableField('Description:', _descriptionController, maxLines: 3),
            const SizedBox(height: 10),
            _buildEditableField('Product Offering:', _productOfferingController, maxLines: 2),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Add functionality to save changes
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.edit, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  final List<String> months = const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    List<Widget> dayWidgets = [];
    int dayCounter = 1;
    int totalCells = ((daysInMonth + startWeekday) / 7).ceil() * 7;

    for (int i = 0; i < totalCells; i++) {
      if (i < startWeekday || dayCounter > daysInMonth) {
        dayWidgets.add(Container());
      } else {
        dayWidgets.add(
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(2),
            child: Text(
              '$dayCounter',
              style: TextStyle(
                color: (selectedMonth == DateTime.now().month && selectedYear == DateTime.now().year && dayCounter == DateTime.now().day)
                    ? Colors.blue
                    : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
        dayCounter++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.only(top: 24.0, left: 8, right: 8, bottom: 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Sales',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.black),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Month and Year pickers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: months[selectedMonth - 1],
                    items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedMonth = months.indexOf(val!) + 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.grey.shade100,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Text('Year:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 6),
                        DropdownButton<int>(
                          value: selectedYear,
                          items: List.generate(5, (i) => selectedYear - 2 + i)
                              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedYear = val!;
                            });
                          },
                          underline: Container(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Calendar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Container(
                      color: Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            months[selectedMonth - 1],
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18),
                          ),
                          Text(
                            '$selectedYear',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.blue, width: 2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('Sun', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Mon', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Tue', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Wed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Thur', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Fri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text('Sat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: dayWidgets,
                      childAspectRatio: 1.2,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Bottom navigation bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(icon: const Icon(Icons.home), color: Colors.grey, onPressed: () {}),
                  IconButton(icon: const Icon(Icons.receipt_long), color: Colors.grey, onPressed: () {}),
                  IconButton(icon: const Icon(Icons.local_shipping), color: Colors.grey, onPressed: () {}),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    color: Colors.blue,
                    onPressed: () {},
                  ),
                  IconButton(icon: const Icon(Icons.person), color: Colors.grey, onPressed: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
