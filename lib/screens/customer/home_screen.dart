import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Your Water Station App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Explore the following features:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.store, size: 40),
                title: const Text('Browse Water Stations'),
                subtitle: const Text('Select and order water from available stations'),
                onTap: () {
                  // Navigate to Water Stations screen (or another screen as needed)
                },
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.local_shipping, size: 40),
                title: const Text('Schedule Water Delivery'),
                subtitle: const Text('Arrange a convenient time for water delivery'),
                onTap: () {
                  // Navigate to Water Delivery screen
                },
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.history, size: 40),
                title: const Text('View Order History'),
                subtitle: const Text('Track your previous orders'),
                onTap: () {
                  // Navigate to Order History screen
                },
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.person, size: 40),
                title: const Text('Manage Your Profile'),
                subtitle: const Text('Update your personal details'),
                onTap: () {
                  // Navigate to Profile screen
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
