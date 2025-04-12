import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import 'waterdeliveryscreen.dart';
import 'waterstationscreen.dart';
import 'manageprofile.dart';
import 'orderhistory_screen.dart';
import 'home_screen.dart';  // Import the new home screen

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  final FirebaseAuth auth = FirebaseAuth.instance;
  User? user;

  // Update the list of pages to include HomeScreen as the first page and 5 pages in total
  static final List<Widget> _pages = [
    HomeScreen(),  // New Home Screen
     WaterDeliveryScreen(),
    WaterStationsScreen(),
    OrderHistoryScreen(), // Switch order and profile positions
    ManageProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    user = auth.currentUser;
  }

  void _onItemTapped(int index) {
    if (index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      print("Invalid index: $index, Pages Length: ${_pages.length}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Customer Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],  // Ensure correct page index

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),  // Home button
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Delivery'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Stations'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Orders'),  // Switch order and profile
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
