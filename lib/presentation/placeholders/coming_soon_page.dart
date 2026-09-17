import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(
            'Cette section sera disponible prochainement.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
