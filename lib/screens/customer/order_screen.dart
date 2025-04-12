import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // To format the orderID

class OrderScreen extends StatefulWidget {
  final QueryDocumentSnapshot station;

  const OrderScreen({super.key, required this.station});

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _quantityController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;

  // New variable to store the selected mode of payment
  String _paymentMode = 'cash';  // Default value is 'cash'

  // Function to generate a unique order ID based on timestamp and random value
  String generateOrderID() {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('MMddyyHHmmss').format(now); // Format as MMDDYYHHMMSS
    final String randomString = (1000 + (10000 * (now.millisecondsSinceEpoch % 1000) / 1000)).toStringAsFixed(0);
    return '$formattedDate$randomString';
  }

  @override
  Widget build(BuildContext context) {
    double pricePerContainer = 50.0; // Example price per container
    double totalPrice = 0.0;

    // Only calculate total price if quantity is entered
    if (_quantityController.text.isNotEmpty) {
      int quantity = int.parse(_quantityController.text);
      totalPrice = quantity * pricePerContainer;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order from ${widget.station['stationName']}'),
      ),
      body: SingleChildScrollView( // Added SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Quantity (Containers of Water)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Quantity',
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),

              // Display the price per container and the calculated total cost
              Text(
                'Price per Container: PHP $pricePerContainer',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Cost: PHP ${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Mode of Payment selection (Radio buttons for cash/online)
              Text(
                'Select Mode of Payment',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Row(
                    children: [
                      Radio<String>(
                        value: 'cash',
                        groupValue: _paymentMode,
                        onChanged: (String? value) {
                          setState(() {
                            _paymentMode = value!;
                          });
                        },
                      ),
                      const Text('Cash')
                    ],
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'online',
                        groupValue: _paymentMode,
                        onChanged: (String? value) {
                          setState(() {
                            _paymentMode = value!;
                          });
                        },
                      ),
                      const Text('Online')
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  if (_quantityController.text.isEmpty) return;

                  int quantity = int.parse(_quantityController.text);

                  User? user = auth.currentUser;
                  if (user == null) return;

                  // Generate unique order ID
                  String orderID = generateOrderID();

                  // Save order to Firestore with the generated orderID and payment mode
                  await FirebaseFirestore.instance.collection('orders').add({
                    'orderID': orderID, // Added orderID field
                    'customerId': user.uid,
                    'customUID': widget.station['customUID'],
                    'stationName': widget.station['stationName'],
                    'orderStatus': 'pending',
                    'orderDate': Timestamp.now(),
                    'quantity': quantity,
                    'totalPrice': totalPrice,
                    'paymentMode': _paymentMode, // Added mode of payment
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order placed successfully!')),
                  );

                  Navigator.pop(context);
                },
                child: const Text('Place Order'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50), // Make the button wide
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
