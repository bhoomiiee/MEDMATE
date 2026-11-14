
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyHealthcareScreen extends StatelessWidget {
  const NearbyHealthcareScreen({super.key});

  Future<void> openMaps(
    BuildContext context,
    String searchQuery,
  ) async {
    final Uri url = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': searchQuery,
      },
    );

    try {
      final opened = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps'),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Maps. Please try again.'),
        ),
      );
    }
  }

  Widget buildServiceCard({
    required BuildContext context,
    required String title,
    required String description,
    required String buttonText,
    required String searchQuery,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 36,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    openMaps(context, searchQuery),
                icon: const Icon(Icons.location_on),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Healthcare'),
        backgroundColor: const Color(0xFF9B83F5),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Healthcare Near You',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Find hospitals, pharmacies and diagnostic '
              'labs near your location.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 24),

            buildServiceCard(
              context: context,
              title: 'Nearby Hospitals',
              description:
                  'Find hospitals and healthcare centres.',
              buttonText: 'Find Hospitals',
              searchQuery: 'hospitals near me',
              icon: Icons.local_hospital,
              color: Colors.red,
            ),

            buildServiceCard(
              context: context,
              title: 'Nearby Pharmacies',
              description:
                  'Find medical stores and pharmacies.',
              buttonText: 'Find Pharmacies',
              searchQuery: 'pharmacies near me',
              icon: Icons.local_pharmacy,
              color: Colors.green,
            ),

            buildServiceCard(
              context: context,
              title: 'Diagnostic Labs',
              description:
                  'Find blood testing and diagnostic centres.',
              buttonText: 'Find Diagnostic Labs',
              searchQuery: 'diagnostic laboratories near me',
              icon: Icons.science,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            const Text(
              'Search results are provided by Google Maps. '
              'Enable location access in Maps for nearby results.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
