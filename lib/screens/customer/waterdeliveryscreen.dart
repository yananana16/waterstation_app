import 'package:flutter/material.dart';

class WaterDeliveryScreen extends StatefulWidget {
  const WaterDeliveryScreen({super.key});

  @override
  _WaterDeliveryScreenState createState() => _WaterDeliveryScreenState();
}

class _WaterDeliveryScreenState extends State<WaterDeliveryScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  bool _isLoading = false;

  Future<void> _requestDelivery() async {
    String address = _addressController.text.trim();
    String quantity = _quantityController.text.trim();

    if (address.isEmpty || quantity.isEmpty) {
      _showMessage("Please fill in all the fields.");
      return;
    }

    setState(() => _isLoading = true);

    // Simulate an API call to request water delivery.
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    // Show success message
    _showMessage("Water delivery requested successfully to $address.");
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Water Delivery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (in liters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _requestDelivery,
                    child: const Text('Request Delivery'),
                  ),
          ],
        ),
      ),
    );
  }
}
