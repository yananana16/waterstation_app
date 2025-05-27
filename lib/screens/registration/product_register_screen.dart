import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Hydrify/screens/station/submit_compliance_screen.dart';

class ProductRegisterScreen extends StatefulWidget {
  final Map<String, dynamic> userDetails;

  const ProductRegisterScreen({Key? key, required this.userDetails}) : super(key: key);

  @override
  State<ProductRegisterScreen> createState() => _ProductRegisterScreenState();
}

class _ProductRegisterScreenState extends State<ProductRegisterScreen> {
  String? selectedWaterType;
  bool isGallonSelected = false;
  String? selectedProductOffer;
  bool isOtherOfferSelected = false;
  String? selectedDeliveryOption;
  bool isLoading = false;

  final TextEditingController otherOfferController = TextEditingController();

  Future<void> _registerUserWithProducts() async {
    if (selectedWaterType == null || selectedDeliveryOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => isLoading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registering...')),
      );

      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Add product data to the "products" subcollection of the registered owner's document
      await _firestore
          .collection('station_owners')
          .doc(widget.userDetails['ownerDocId']) // Use the document ID of the registered owner
          .collection('products')
          .add({
        'waterType': selectedWaterType,
        'gallon': isGallonSelected,
        'productOffer': selectedProductOffer,
        'otherOffer': isOtherOfferSelected ? otherOfferController.text : null,
        'deliveryAvailable': selectedDeliveryOption,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered successfully!')),
      );

      // Navigate to SubmitComplianceScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SubmitCompliancePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    otherOfferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Registration'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Register Your Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Types of Water',
                  border: OutlineInputBorder(),
                ),
                value: selectedWaterType,
                items: ['Mineral', 'Purified', 'Distilled']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => selectedWaterType = value),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Offer:', style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('Gallon'),
                      value: isGallonSelected,
                      onChanged: (value) => setState(() => isGallonSelected = value ?? false),
                    ),
                    RadioListTile<String>(
                      title: const Text('Round'),
                      value: 'Round',
                      groupValue: selectedProductOffer,
                      onChanged: (value) => setState(() => selectedProductOffer = value),
                    ),
                    RadioListTile<String>(
                      title: const Text('Slim'),
                      value: 'Slim',
                      groupValue: selectedProductOffer,
                      onChanged: (value) => setState(() => selectedProductOffer = value),
                    ),
                    CheckboxListTile(
                      title: const Text('Other offer:'),
                      value: isOtherOfferSelected,
                      onChanged: (value) => setState(() => isOtherOfferSelected = value ?? false),
                    ),
                    if (isOtherOfferSelected)
                      TextField(
                        controller: otherOfferController,
                        decoration: const InputDecoration(
                          labelText: 'Please Specify',
                          border: OutlineInputBorder(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Delivery Available',
                  border: OutlineInputBorder(),
                ),
                value: selectedDeliveryOption,
                items: ['Yes', 'No']
                    .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) => setState(() => selectedDeliveryOption = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _registerUserWithProducts,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
