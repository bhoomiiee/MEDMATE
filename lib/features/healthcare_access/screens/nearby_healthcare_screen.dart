import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => openMaps(context, searchQuery),
              icon: const Icon(Icons.location_on_outlined),
              label: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 44,
          ),
          SizedBox(height: 16),
          Text(
            'Healthcare Near You',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find hospitals, pharmacies and diagnostic '
            'labs near your location.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Healthcare'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildHeader(),
                  const SizedBox(height: 24),
                  Text(
                    'Healthcare Services',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  buildServiceCard(
                    context: context,
                    title: 'Nearby Hospitals',
                    description: 'Find hospitals and healthcare centres.',
                    buttonText: 'Find Hospitals',
                    searchQuery: 'hospitals near me',
                    icon: Icons.local_hospital,
                    color: AppColors.error,
                  ),
                  buildServiceCard(
                    context: context,
                    title: 'Nearby Pharmacies',
                    description: 'Find medical stores and pharmacies.',
                    buttonText: 'Find Pharmacies',
                    searchQuery: 'pharmacies near me',
                    icon: Icons.local_pharmacy,
                    color: AppColors.secondary,
                  ),
                  buildServiceCard(
                    context: context,
                    title: 'Diagnostic Labs',
                    description: 'Find blood testing and diagnostic centres.',
                    buttonText: 'Find Diagnostic Labs',
                    searchQuery: 'diagnostic laboratories near me',
                    icon: Icons.science,
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search results are provided by Google Maps. '
                            'Enable location access in Maps for nearby results.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
