import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'station_details_screen.dart'; // Import the new screen for station details

class WaterStationsScreen extends StatelessWidget {
  const WaterStationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Stations'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'station_owner')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No approved water stations found.'));
          }

          final stations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: stations.length,
            itemBuilder: (context, index) {
              var station = stations[index];

              // Extract GeoPoint location
              GeoPoint? geoPoint = station['location'];
              String locationText = geoPoint != null
                  ? 'Lat: ${geoPoint.latitude}, Lng: ${geoPoint.longitude}'
                  : 'Location not available';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.local_drink, color: Colors.blue),
                  title: Text(
                    station['stationName'] ?? 'Unknown Station',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(locationText),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () {
                    // Navigate to the station details screen when a station is selected
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StationDetailsScreen(station: station),
                      ),
                    );
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
