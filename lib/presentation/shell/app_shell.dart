import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../dashboard/dashboard_page.dart';
import '../placeholders/coming_soon_page.dart';
import '../theme/app_colors.dart';
import 'app_destinations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _destination = AppDestination.today;

  void _select(AppDestination destination) {
    if (destination == AppDestination.today &&
        _destination != AppDestination.today) {
      ref.invalidate(dashboardSnapshotProvider);
    }
    setState(() {
      _destination = destination;
    });
  }

  @override
  Widget build(BuildContext context) {
    final badgeCount = ref.watch(dashboardSnapshotProvider).maybeWhen(
      data: (snapshot) => snapshot.badgeCount,
      orElse: () => 0,
    );

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            destination: _destination,
            badgeCount: badgeCount,
            onSelect: _select,
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.ivory,
              child: IndexedStack(
                index: _destination.index,
                children: [
                  DashboardPage(
                    onSeeAllClients: () => _select(AppDestination.clients),
                  ),
                  const ComingSoonPage(title: 'Clients & Pianos'),
                  const ComingSoonPage(title: 'Historique'),
                  const ComingSoonPage(title: 'Paramètres'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destination,
    required this.badgeCount,
    required this.onSelect,
  });

  final AppDestination destination;
  final int badgeCount;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.forest,
      child: SizedBox(
        width: 232,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Brand(),
                const SizedBox(height: 36),
                _NavItem(
                  label: 'Aujourd’hui',
                  selected: destination == AppDestination.today,
                  badgeCount: badgeCount,
                  onPressed: () => onSelect(AppDestination.today),
                ),
                _NavItem(
                  label: 'Clients & Pianos',
                  selected: destination == AppDestination.clients,
                  onPressed: () => onSelect(AppDestination.clients),
                ),
                _NavItem(
                  label: 'Historique',
                  selected: destination == AppDestination.history,
                  onPressed: () => onSelect(AppDestination.history),
                ),
                _NavItem(
                  label: 'Paramètres',
                  selected: destination == AppDestination.settings,
                  onPressed: () => onSelect(AppDestination.settings),
                ),
                const Spacer(),
                Text(
                  'Saison 2026-2027',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onForest.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'Assets/logoApp.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: AppColors.forestMid,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.piano, color: AppColors.onForest, size: 22),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Pianos d’Occitanie',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.onForest,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = badgeCount > 0 && label == 'Aujourd’hui'
        ? '$label, $badgeCount rappels à traiter'
        : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.forestActive : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          focusColor: AppColors.focus.withValues(alpha: 0.35),
          child: Semantics(
            button: true,
            selected: selected,
            label: semanticsLabel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onForest,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.badge,
                        foregroundColor: Colors.white,
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
