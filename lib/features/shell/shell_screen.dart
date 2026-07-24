import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/config/app_edition.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/theme/app_theme.dart';

class ShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;
  const ShellScreen({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  void _onDestinationSelected(BuildContext context, int index) {
    if (!AppFeatures.sosCallsEnabled) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
      return;
    }
    if (index == 2) {
      context.push('/sos');
    } else {
      final branch = index < 2 ? index : index - 1;
      navigationShell.goBranch(
        branch,
        initialLocation: branch == navigationShell.currentIndex,
      );
    }
  }

  int _getSelectedIndex() {
    final cur = navigationShell.currentIndex;
    if (!AppFeatures.sosCallsEnabled) return cur;
    return cur < 2 ? cur : cur + 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final dests = [
      NavigationDestinationData(
        icon: Icons.home_outlined,
        selected: Icons.home,
        label: t.text('nav.home'),
      ),
      NavigationDestinationData(
        icon: Icons.map_outlined,
        selected: Icons.map,
        label: t.text('nav.map'),
      ),
      if (AppFeatures.sosCallsEnabled)
        NavigationDestinationData(
          icon: Icons.emergency,
          selected: Icons.emergency,
          label: t.text('nav.sos'),
          isSpecial: true,
        ),
      NavigationDestinationData(
        icon: Icons.campaign_outlined,
        selected: Icons.campaign,
        label: t.text('nav.advisory'),
      ),
      NavigationDestinationData(
        icon: Icons.person_outline,
        selected: Icons.person,
        label: t.text('nav.profile'),
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: AnimatedIndexedStack(
                index: navigationShell.currentIndex,
                children: children,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GlassmorphicNavbar(
                    selectedIndex: _getSelectedIndex(),
                    destinations: dests,
                    onDestinationSelected: (index) =>
                        _onDestinationSelected(context, index),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });
  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _animations = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
    _controllers[widget.index].value = 1.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controllers[oldWidget.index].reverse();
      _controllers[widget.index].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (index) {
        final isSelected = index == widget.index;
        return FadeTransition(
          opacity: _animations[index],
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(_animations[index]),
            child: KeyedSubtree(
              key: ValueKey(index),
              child: IgnorePointer(
                ignoring: !isSelected,
                child: TickerMode(
                  enabled: isSelected || _controllers[index].isAnimating,
                  child: widget.children[index],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class NavigationDestinationData {
  final IconData icon, selected;
  final String label;
  final bool isSpecial;
  const NavigationDestinationData({
    required this.icon,
    required this.selected,
    required this.label,
    this.isSpecial = false,
  });
}

class GlassmorphicNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationData> destinations;
  const GlassmorphicNavbar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: Alignment(
              -1.0 + (selectedIndex * (2.0 / (destinations.length - 1))),
              0.0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / destinations.length,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(destinations.length, (index) {
              final isSelected = index == selectedIndex;
              final item = destinations[index];
              if (item.isSpecial) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDestinationSelected(index),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x40EF4444),
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emergency,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDestinationSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.12 : 1.0,
                        child: Icon(
                          isSelected ? item.selected : item.icon,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF94A3B8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
