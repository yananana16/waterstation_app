import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: user == null
          ? const Center(child: Text('Please log in to view your orders.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: user.uid) // Get only user's orders
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }

                // Fetch orders from Firestore
                var orders = snapshot.data!.docs;

                // Sort orders by orderDate manually in Flutter (descending order)
                orders.sort((a, b) => (b['orderDate'] as Timestamp)
                    .compareTo(a['orderDate'] as Timestamp));

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    var order = orders[index];
                    String status = order['orderStatus'];
                    double total = order['totalPrice']; // Ensure correct key
                    DateTime date = (order['orderDate'] as Timestamp).toDate();
                    String orderID = order['orderID']; // Fetch the orderID field

                    Color statusColor = Colors.orange;
                    if (status == "Completed") statusColor = Colors.green;
                    if (status == "Cancelled") statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Order #$orderID'), // Use orderID here
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total: PHP $total'),
                            Text('Date: ${date.toLocal()}'),
                            Text(
                              'Status: $status',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Future: Navigate to order details page
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
