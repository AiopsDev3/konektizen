import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/theme/app_theme.dart';

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == 1) {
      // Index 1 is SOS - Full Screen Action
      context.push('/sos');
    } else {
      // Map other indices to branches
      // Nav 0 (Home) -> Branch 0
      // Nav 2 (Cases) -> Branch 1
      // Nav 3 (Profile) -> Branch 2
      int branchIndex = index;
      if (index > 1) branchIndex = index - 1; // 2->1, 3->2
      
      navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell.currentIndex,
      );
    }
  }

  int _getSelectedIndex() {
    // Map branch index to nav index
    // Branch 0 (Home) -> Nav 0
    // Branch 1 (Cases) -> Nav 2
    // Branch 2 (Profile) -> Nav 3
    final current = navigationShell.currentIndex;
    if (current == 0) return 0;
    if (current == 1) return 2;
    if (current == 2) return 3;
    return 0; // Default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.tertiary.withOpacity(0.3),
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
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: AppTheme.secondary),
            label: 'My Cases',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.secondary),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
      ),
    );
  }
}
