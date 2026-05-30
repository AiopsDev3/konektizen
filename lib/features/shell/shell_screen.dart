import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/theme/app_theme.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == 1) {
      context.push('/sos');
    } else {
      final branchIndex = index == 0 ? 0 : index - 1;

      navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell.currentIndex,
      );
    }
  }

  int _getSelectedIndex() {
    // Map branch index to nav index
    // Branch 0 (Home) -> Nav 0
    // Branch 1 (Map) -> Nav 2
    // Branch 2 (Advisory) -> Nav 3
    // Branch 3 (Profile) -> Nav 4
    final current = navigationShell.currentIndex;
    if (current == 0) return 0;
    if (current == 1) return 2;
    if (current == 2) return 3;
    if (current == 3) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.tertiary.withValues(alpha: 0.3),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.secondary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: Colors.white, size: 24),
            ),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppTheme.secondary),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign, color: AppTheme.secondary),
            label: 'Advisory',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.secondary),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
      ),
    );
  }
}
