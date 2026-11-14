
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GovernmentSchemesScreen extends StatelessWidget {
  const GovernmentSchemesScreen({super.key});

  Future<void> openWebsite(
    BuildContext context,
    String website,
  ) async {
    try {
      final success = await launchUrl(
        Uri.parse(website),
        mode: LaunchMode.externalApplication,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open website'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open website'),
        ),
      );
    }
  }

  Widget buildSchemeCard({
    required BuildContext context,
    required String title,
    required String description,
    required String benefits,
    required String eligibility,
    required String website,
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 16),

            const Text(
              'Benefits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(benefits),

            const SizedBox(height: 16),

            const Text(
              'Eligibility / Access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(eligibility),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    openWebsite(context, website),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Visit Official Website'),
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
        title: const Text('Government Health Schemes'),
        backgroundColor: const Color(0xFF9B83F5),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Healthcare for Everyone',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Discover government healthcare schemes '
              'and services available in India.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 24),

            // Scheme 1 - Ayushman Bharat
            buildSchemeCard(
              context: context,
              title: 'Ayushman Bharat - PM-JAY',
              description:
                  'Government health assurance scheme.',
              benefits:
                  'Hospitalisation coverage of up to '
                  '₹5 lakh per eligible family per year '
                  'for covered treatments.',
              eligibility:
                  'Eligible beneficiary families and '
                  'senior citizens aged 70 years and above. '
                  'Check the official portal for details.',
              website: 'https://beneficiary.nha.gov.in/',
              icon: Icons.health_and_safety,
              color: Colors.green,
            ),

            // Scheme 2 - ABHA
            buildSchemeCard(
              context: context,
              title: 'ABHA Health Account',
              description:
                  'Digital health identity under the '
                  'Ayushman Bharat Digital Mission.',
              benefits:
                  'Access and share linked digital '
                  'health records with consent.',
              eligibility:
                  'Voluntary registration through the '
                  'official ABHA portal. ABHA is not '
                  'health insurance.',
              website: 'https://abha.abdm.gov.in/',
              icon: Icons.badge,
              color: Colors.blue,
            ),

            // Scheme 3 - Jan Aushadhi
            buildSchemeCard(
              context: context,
              title: 'Jan Aushadhi',
              description:
                  'Pradhan Mantri Bhartiya Janaushadhi '
                  'Pariyojana.',
              benefits:
                  'Affordable generic medicines through '
                  'Jan Aushadhi Kendras.',
              eligibility:
                  'Open to the public. Prescription '
                  'requirements apply where necessary.',
              website: 'https://janaushadhi.gov.in/',
              icon: Icons.medication,
              color: Colors.orange.shade800,
            ),

            // Scheme 4 - eSanjeevani
            buildSchemeCard(
              context: context,
              title: 'eSanjeevani',
              description:
                  'National government telemedicine service.',
              benefits:
                  'Online consultations with healthcare '
                  'professionals, subject to availability.',
              eligibility:
                  'Register as a patient through '
                  'the official service.',
              website: 'https://esanjeevani.mohfw.gov.in/',
              icon: Icons.video_call,
              color: Colors.deepPurple,
            ),

            // Scheme 5 - Arogya Karnataka
            buildSchemeCard(
              context: context,
              title: 'Ayushman Bharat Arogya Karnataka',
              description:
                  'Government healthcare support '
                  'for Karnataka residents.',
              benefits:
                  'Access to healthcare services and '
                  'covered treatments under applicable rules.',
              eligibility:
                  'Benefits depend on residency, '
                  'beneficiary category and scheme rules.',
              website:
                  'https://bengaluruurban.nic.in/en/healthdept/ayushman-bharth-arogya-karnataka/',
              icon: Icons.local_hospital,
              color: Colors.teal,
            ),

            const SizedBox(height: 12),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Disclaimer: MedMate provides general '
                  'information only. Scheme benefits and '
                  'eligibility may change. Verify details '
                  'on official government websites. '
                  'MedMate does not approve applications '
                  'or guarantee coverage.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
