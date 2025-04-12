import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_screen.dart'; // Import the order screen

class StationDetailsScreen extends StatelessWidget {
  final QueryDocumentSnapshot station;

  const StationDetailsScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    // Accessing the station details
    String firstName = station['firstName'] ?? 'Unknown';
    String lastName = station['lastName'] ?? 'Unknown';
    String stationName = station['stationName'] ?? 'Unknown Station';

    // Extract GeoPoint location
    GeoPoint? geoPoint = station['location'];
    String locationText = geoPoint != null
        ? 'Lat: ${geoPoint.latitude}, Lng: ${geoPoint.longitude}'
        : 'Location not available';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Name: $stationName',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Owner: $firstName $lastName',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              'Location: $locationText',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // Button to go to the order screen
            ElevatedButton(
              onPressed: () {
                // Navigate to the order screen when button is pressed
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderScreen(station: station),
                  ),
                );
              },
              child: const Text('Order from this Station'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Full-width button
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
